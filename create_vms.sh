#!/bin/bash

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# Ask if this is the first time running the script
read -p "Is this the first time you are running this script? Do you want to install prerequisites? (y/n): " INSTALL_PREREQUISITES
if [[ "$INSTALL_PREREQUISITES" == "y" || "$INSTALL_PREREQUISITES" == "Y" ]]; then
  echo -e "${CYAN}🔧 Installing prerequisites...${RESET}"
  chmod +x prerequisites.sh
  ./prerequisites.sh
fi

# Absolute current directory
SCRIPT_DIR="$(pwd)"

# Load configuration from config.json
INTERFACE=$(jq -r '.interface' config.json)
DOMAIN=$(jq -r '.domain' config.json)

echo -e "${CYAN}🧹 Cleaning up existing VMs with the same name...${RESET}"
for VM in $(jq -r '.vms[]' config.json | jq -r '.name'); do
  echo -e "${YELLOW}Analyzing VM: $VM with Ubuntu 22.04${RESET}"

  if multipass info "$VM" &>/dev/null; then
    echo -e "${CYAN}Deleting existing VM: $VM${RESET}"
    multipass delete "$VM"
  fi
done

multipass purge

echo -e "${CYAN}⚙️  Generating cloud-init and inventory...${RESET}"
python3 generate_cloud_init.py

echo -e "${CYAN}🚀 Launching VMs...${RESET}"
for VM in $(jq -c '.vms[]' config.json); do
  NAME=$(echo "$VM" | jq -r '.name')
  CPUS=$(echo "$VM" | jq -r '.cpus')
  MEMORY=$(echo "$VM" | jq -r '.memory')
  DISK=$(echo "$VM" | jq -r '.disk')

  echo -e "${GREEN}Launching VM: $NAME${RESET}"
  multipass launch 22.04 --name "$NAME" \
    --cpus "$CPUS" --memory "$MEMORY" --disk "$DISK" \
    --cloud-init "cloud-init/$NAME.yaml" \
    --timeout 300
done

# Generate the inventory.ini file
echo -e "${CYAN}⚙️  Generating inventory.ini file...${RESET}"
echo "[lab]" > inventory.ini
for VM in $(jq -r '.vms[]' config.json | jq -r '.name'); do
  IP=$(multipass info "$VM" | grep "IPv4" | awk '{print $2}')
  if [[ -n "$IP" ]]; then
    echo "$VM.$DOMAIN ansible_host=$IP ansible_user=root ansible_ssh_private_key_file=ssh_keys/id_rsa" >> inventory.ini
  else
    echo -e "${YELLOW}Warning: No IP found for VM '$VM'. Skipping.${RESET}"
  fi
done

echo -e "${CYAN}🔧 Configuring with Ansible...${RESET}"
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini ansible/playbook.yml

# Final output with VM details
echo -e "\n${CYAN}🎉 All set! VM details:${RESET}"

multipass list --format json | jq -r '.list[] | select(.state == "Running") | "\(.name) \(.ipv4[0])"' | while read name ip; do
  echo -e "${YELLOW}$name${RESET} - IP: ${GREEN}$ip${RESET}"
  echo -e "   ➤ SSH: ${CYAN}ssh -i ${SCRIPT_DIR}/ssh_keys/id_rsa root@$ip${RESET}"
done

echo -e "\n${GREEN}✅ Setup completed successfully.${RESET}"
