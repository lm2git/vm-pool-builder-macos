#!/bin/bash

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

# Absolute current directory
SCRIPT_DIR="$(pwd)"
CONFIG_FILE="config.json"

# Ensure config.json exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}Error: $CONFIG_FILE not found!${RESET}"
  exit 1
fi

# Load configuration from config.json
INTERFACE=$(jq -r '.interface' "$CONFIG_FILE")
DOMAIN=$(jq -r '.domain' "$CONFIG_FILE")

# Get desired VM names from config.json
DESIRED_VMS=$(jq -r '.vms[].name' "$CONFIG_FILE")

# Get current VMs from Multipass
CURRENT_VMS=$(multipass list --format json | jq -r '.list[].name')

echo -e "${CYAN}🔄 Reconciling VM pool with config.json...${RESET}"

# Remove VMs not in config.json
for VM in $CURRENT_VMS; do
  if ! echo "$DESIRED_VMS" | grep -q "^$VM$"; then
    echo -e "${YELLOW}Deleting VM not in config.json: $VM${RESET}"
    multipass delete "$VM"
  fi
done

# Purge deleted VMs
multipass purge

# Add or update VMs based on config.json
for VM_CONFIG in $(jq -c '.vms[]' "$CONFIG_FILE"); do
  NAME=$(echo "$VM_CONFIG" | jq -r '.name')
  CPUS=$(echo "$VM_CONFIG" | jq -r '.cpus')
  MEMORY=$(echo "$VM_CONFIG" | jq -r '.memory')
  DISK=$(echo "$VM_CONFIG" | jq -r '.disk')

  if echo "$CURRENT_VMS" | grep -q "^$NAME$"; then
    echo -e "${CYAN}Updating existing VM: $NAME${RESET}"
    multipass stop "$NAME"
    multipass delete "$NAME"
    multipass purge
  else
    echo -e "${GREEN}Creating new VM: $NAME${RESET}"
  fi

  # Generate cloud-init file
  echo -e "${CYAN}Generating cloud-init for $NAME...${RESET}"
  python3 generate_cloud_init.py "$NAME"

  # Launch VM
  multipass launch 22.04 --name "$NAME" \
    --cpus "$CPUS" --memory "$MEMORY" --disk "$DISK" \
    --cloud-init "cloud-init/$NAME.yaml" \
    --timeout 300
done

# Generate the inventory.ini file
echo -e "${CYAN}⚙️  Regenerating inventory.ini file...${RESET}"
echo "[lab]" > inventory.ini
for VM in $DESIRED_VMS; do
  IP=$(multipass info "$VM" | grep "IPv4" | awk '{print $2}')
  if [[ -n "$IP" ]]; then
    echo "$VM.$DOMAIN ansible_host=$IP ansible_user=root ansible_ssh_private_key_file=ssh_keys/id_rsa" >> inventory.ini
  else
    echo -e "${YELLOW}Warning: No IP found for VM '$VM'. Skipping.${RESET}"
  fi
done

# Apply Ansible playbook
echo -e "${CYAN}🔧 Applying Ansible configuration...${RESET}"
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini ansible/playbook.yml

# Final output with VM details
echo -e "\n${CYAN}🎉 Reconciliation complete! VM details:${RESET}"
multipass list --format json | jq -r '.list[] | select(.state == "Running") | "\(.name) \(.ipv4[0])"' | while read name ip; do
  echo -e "${YELLOW}$name${RESET} - IP: ${GREEN}$ip${RESET}"
  echo -e "   ➤ SSH: ${CYAN}ssh -i ${SCRIPT_DIR}/ssh_keys/id_rsa root@$ip${RESET}"
done

echo -e "\n${GREEN}✅ Reconciliation completed successfully.${RESET}"
