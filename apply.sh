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
function check_config_file() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Error: $CONFIG_FILE not found!${RESET}"
    exit 1
  fi
}

# Load configuration
function load_config() {
  INTERFACE=$(jq -r '.interface' "$CONFIG_FILE")
  DOMAIN=$(jq -r '.domain' "$CONFIG_FILE")
  DESIRED_VMS=$(jq -r '.vms[].name' "$CONFIG_FILE")
}

# Get current VMs from Multipass
function get_current_vms() {
  CURRENT_VMS=$(multipass list --format json | jq -r '.list[].name')
}

# Remove VMs not in config.json
function remove_unwanted_vms() {
  for VM in $CURRENT_VMS; do
    if ! echo "$DESIRED_VMS" | grep -q "^$VM$"; then
      echo -e "${YELLOW}Deleting VM not in config.json: $VM${RESET}"
      multipass delete "$VM"
    fi
  done
  multipass purge
}

# Ensure SSH keys exist
function ensure_ssh_keys() {
  if [[ ! -f "ssh_keys/id_rsa" || ! -f "ssh_keys/id_rsa.pub" ]]; then
    echo -e "${YELLOW}SSH keys not found. Generating new SSH keys...${RESET}"
    mkdir -p ssh_keys
    ssh-keygen -t rsa -b 2048 -f ssh_keys/id_rsa -q -N ""
  fi
}

# Update or create VMs
function reconcile_vms() {
  for VM_CONFIG in $(jq -c '.vms[]' "$CONFIG_FILE"); do
    NAME=$(echo "$VM_CONFIG" | jq -r '.name')
    CPUS=$(echo "$VM_CONFIG" | jq -r '.cpus')
    MEMORY=$(echo "$VM_CONFIG" | jq -r '.memory')
    DISK=$(echo "$VM_CONFIG" | jq -r '.disk')

    if echo "$CURRENT_VMS" | grep -q "^$NAME$"; then
      update_vm "$NAME" "$CPUS" "$MEMORY" "$DISK"
    else
      create_vm "$NAME" "$CPUS" "$MEMORY" "$DISK"
    fi
  done
}

# Update an existing VM
function update_vm() {
  local NAME=$1
  local CPUS=$2
  local MEMORY=$3
  local DISK=$4

  echo -e "${CYAN}Updating existing VM: $NAME${RESET}"
  CURRENT_CPUS=$(multipass info "$NAME" | grep "CPUs" | awk '{print $2}')
  CURRENT_MEMORY=$(multipass info "$NAME" | grep "Memory" | awk '{print $2}')
  CURRENT_DISK=$(multipass info "$NAME" | grep "Disk" | awk '{print $2}')

  if [[ "$CURRENT_CPUS" != "$CPUS" || "$CURRENT_MEMORY" != "$MEMORY" || "$CURRENT_DISK" != "$DISK" ]]; then
    echo -e "${YELLOW}VM $NAME requires updates to specifications.${RESET}"

    if [[ "$CURRENT_CPUS" != "$CPUS" || "$CURRENT_MEMORY" != "$MEMORY" || "$CURRENT_DISK" != "$DISK" ]]; then
      echo -e "${YELLOW}Skipping updates that require stopping and starting VM: $NAME.${RESET}"
      return
    fi

    # Apply updates that do not require stopping the VM
    [[ "$CURRENT_CPUS" != "$CPUS" ]] && multipass set "local.$NAME.cpus=$CPUS"
    [[ "$CURRENT_MEMORY" != "$MEMORY" ]] && multipass set "local.$NAME.memory=$MEMORY"
    [[ "$CURRENT_DISK" != "$DISK" ]] && multipass set "local.$NAME.disk=$DISK"

    echo -e "${GREEN}Updated specifications for VM: $NAME.${RESET}"
  else
    echo -e "${GREEN}VM $NAME already matches the desired specifications. Skipping update.${RESET}"
  fi
}

# Create a new VM
function create_vm() {
  local NAME=$1
  local CPUS=$2
  local MEMORY=$3
  local DISK=$4

  echo -e "${GREEN}Creating new VM: $NAME${RESET}"
  echo -e "${CYAN}Generating cloud-init for $NAME...${RESET}"
  mkdir -p cloud-init
  if ! python3 generate_cloud_init.py "$NAME"; then
    echo -e "${RED}Error: Failed to generate cloud-init for $NAME. Skipping VM creation.${RESET}"
    return
  fi

  if ! multipass launch 22.04 --name "$NAME" \
    --cpus "$CPUS" --memory "$MEMORY" --disk "$DISK" \
    --cloud-init "cloud-init/$NAME.yaml" \
    --timeout 300; then
    echo -e "${RED}Error: Failed to launch VM $NAME. Skipping.${RESET}"
  fi
}

# Generate inventory.ini
function generate_inventory() {
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
}

# Apply Ansible playbook
function apply_ansible_playbook() {
  echo -e "${CYAN}🔧 Applying Ansible configuration...${RESET}"
  ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini ansible/playbook.yml
}

# Display final VM details
function display_vm_details() {
  echo -e "\n${CYAN}🎉 Reconciliation complete! VM details:${RESET}"
  multipass list --format json | jq -r '.list[] | select(.state == "Running") | "\(.name) \(.ipv4[0])"' | while read name ip; do
    echo -e "${YELLOW}$name${RESET} - IP: ${GREEN}$ip${RESET}"
    echo -e "   ➤ SSH: ${CYAN}ssh -i ${SCRIPT_DIR}/ssh_keys/id_rsa root@$ip${RESET}"
  done
  echo -e "\n${GREEN}✅ Reconciliation completed successfully.${RESET}"
}

# Main script execution
function main() {
  check_config_file
  load_config
  get_current_vms
  echo -e "${CYAN}🔄 Reconciling VM pool with config.json...${RESET}"
  remove_unwanted_vms
  ensure_ssh_keys
  reconcile_vms
  generate_inventory
  apply_ansible_playbook
  display_vm_details
}

main
