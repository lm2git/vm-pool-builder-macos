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

# Ensure config.json exists and is valid
function check_config_file() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Error: $CONFIG_FILE not found!${RESET}"
    exit 1
  fi

  if ! jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
    echo -e "${RED}Error: $CONFIG_FILE is not a valid JSON file!${RESET}"
    exit 1
  fi

  # Validate required fields
  if ! jq -e '.vms[] | .name and .cpus and .memory and .disk' "$CONFIG_FILE" >/dev/null 2>&1; then
    echo -e "${RED}Error: $CONFIG_FILE is missing required VM fields (name, cpus, memory, disk)!${RESET}"
    exit 1
  fi

  # Check for duplicate VM names
  if jq -r '.vms[].name' "$CONFIG_FILE" | sort | uniq -d | grep -q .; then
    echo -e "${RED}Error: Duplicate VM names found in $CONFIG_FILE!${RESET}"
    exit 1
  fi

  # Check for disk values without "G" unit
  if jq -r '.vms[].disk' "$CONFIG_FILE" | grep -vE '^[0-9]+G$' | grep -q .; then
    echo -e "${RED}Error: Disk values must include the 'G' unit (e.g., '10G') in $CONFIG_FILE!${RESET}"
    exit 1
  fi

  # Check for additional schema errors
  if ! jq -e '.vms[] | select(.name and .cpus and .memory and .disk)' "$CONFIG_FILE" >/dev/null 2>&1; then
    echo -e "${RED}Error: $CONFIG_FILE contains invalid VM schema! Ensure all VMs have name, cpus, memory, and disk fields.${RESET}"
    exit 1
  fi
}

# Load configuration
function load_config() {
  INTERFACE=$(jq -r '.interface' "$CONFIG_FILE")
  DOMAIN=$(jq -r '.domain // empty' "$CONFIG_FILE")
  BASE_DOMAIN=$(jq -r '.baseDomain // empty' "$CONFIG_FILE")
  DESIRED_VMS=$(jq -r '.vms[].name' "$CONFIG_FILE")
}

# Prompt for baseDomain if not set and update config.json
function ensure_base_domain() {
  BASE_DOMAIN=$(jq -r '.baseDomain // empty' "$CONFIG_FILE")
  if [[ -z "$BASE_DOMAIN" || "$BASE_DOMAIN" == "null" ]]; then
    echo -e "${CYAN}Enter base domain to use for FQDN (e.g. example.local):${RESET}"
    read -r BASE_DOMAIN
    if [[ -z "$BASE_DOMAIN" ]]; then
      echo -e "${RED}Error: baseDomain is required!${RESET}"
      exit 1
    fi
    # Update config.json with baseDomain
    tmp=$(mktemp)
    jq --arg bd "$BASE_DOMAIN" '.baseDomain = $bd' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
  fi
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

  echo -e "${CYAN}Checking existing VM: $NAME${RESET}"
  CURRENT_CPUS=$(multipass info "$NAME" | grep "CPUs" | awk '{print $2}')
  CURRENT_MEMORY=$(multipass info "$NAME" | grep "Memory" | awk '{print $2}')
  CURRENT_DISK=$(multipass info "$NAME" | grep "Disk" | awk '{print $2}')

  # Skip update if current specs match desired specs
  if [[ "$CURRENT_CPUS" == "$CPUS" && "$CURRENT_MEMORY" == "$MEMORY" && "$CURRENT_DISK" == "$DISK" ]]; then
    echo -e "${GREEN}VM $NAME already matches the desired specifications. Skipping update.${RESET}"
    return
  fi

  echo -e "${YELLOW}Updating specifications for VM: $NAME...${RESET}"
  multipass stop "$NAME"

  [[ "$CURRENT_CPUS" != "$CPUS" ]] && multipass set "local.$NAME.cpus=$CPUS"
  [[ "$CURRENT_MEMORY" != "$MEMORY" ]] && multipass set "local.$NAME.memory=$MEMORY"
  [[ "$CURRENT_DISK" != "$DISK" ]] && multipass set "local.$NAME.disk=$DISK"

  multipass start "$NAME"
  echo -e "${GREEN}Updated specifications for VM: $NAME.${RESET}"
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
      echo "$VM.$BASE_DOMAIN ansible_host=$IP ansible_user=root ansible_ssh_private_key_file=ssh_keys/id_rsa" >> inventory.ini
    else
      echo -e "${YELLOW}Warning: No IP found for VM '$VM'. Skipping.${RESET}"
    fi
  done
}

# Update /etc/hosts on the host
function update_local_hosts() {
  echo -e "${CYAN}Updating /etc/hosts on the host...${RESET}"
  TMP_HOSTS=$(mktemp)
  sudo cp /etc/hosts "$TMP_HOSTS"
  # Remove old managed entries
  sudo sed -i '' '/# VM-POOL-BEGIN/,/# VM-POOL-END/d' "$TMP_HOSTS"
  echo "# VM-POOL-BEGIN" | sudo tee -a "$TMP_HOSTS" >/dev/null
  for VM in $DESIRED_VMS; do
    IP=$(multipass info "$VM" | grep "IPv4" | awk '{print $2}')
    if [[ -n "$IP" ]]; then
      echo "$IP $VM $VM.$BASE_DOMAIN" | sudo tee -a "$TMP_HOSTS" >/dev/null
    fi
  done
  echo "# VM-POOL-END" | sudo tee -a "$TMP_HOSTS" >/dev/null
  sudo cp "$TMP_HOSTS" /etc/hosts
  rm "$TMP_HOSTS"
}

# Update /etc/hosts inside each VM
function update_vm_hosts() {
  echo -e "${CYAN}Updating /etc/hosts inside each VM...${RESET}"
  for VM in $DESIRED_VMS; do
    IP=$(multipass info "$VM" | grep "IPv4" | awk '{print $2}')
    if [[ -n "$IP" ]]; then
      multipass exec "$VM" -- bash -c "sudo sed -i '/# VM-POOL-BEGIN/,/# VM-POOL-END/d' /etc/hosts"
      multipass exec "$VM" -- bash -c "echo '# VM-POOL-BEGIN' | sudo tee -a /etc/hosts"
      for VM2 in $DESIRED_VMS; do
        IP2=$(multipass info "$VM2" | grep "IPv4" | awk '{print $2}')
        if [[ -n \"\$IP2\" ]]; then
          multipass exec "$VM" -- bash -c \"echo '\$IP2 $VM2 $VM2.$BASE_DOMAIN' | sudo tee -a /etc/hosts\"
        fi
      done
      multipass exec "$VM" -- bash -c "echo '# VM-POOL-END' | sudo tee -a /etc/hosts"
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

# Run prerequisites if the user agrees
function run_prerequisites() {
  echo -e "${CYAN}Do you want to run dependencies and prerequisites? (y/n)${RESET}"
  read -r RESPONSE
  if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}Running prerequisites...${RESET}"
    if [[ -f "scripts/prerequisites.sh" ]]; then
      chmod +x scripts/prerequisites.sh
      ./scripts/prerequisites.sh
    else
      echo -e "${RED}Error: prerequisites.sh not found in the scripts folder!${RESET}"
      exit 1
    fi
  else
    echo -e "${YELLOW}Skipping prerequisites.${RESET}"
  fi
}

# Display help message
function display_help() {
  echo -e "${CYAN}Usage: ./apply.sh [OPTIONS]${RESET}"
  echo -e "${CYAN}Options:${RESET}"
  echo -e "  ${YELLOW}--help${RESET}       Display this help message."
  echo -e "  ${YELLOW}--shutdown${RESET}   Stop all VMs listed in config.json."
  echo -e "  ${YELLOW}--cleanup${RESET}    Remove all VMs managed by the script."
  exit 0
}

# Stop all VMs listed in config.json
function shutdown_vms() {
  echo -e "${CYAN}🔄 Stopping all VMs listed in config.json...${RESET}"
  for VM in $DESIRED_VMS; do
    echo -e "${YELLOW}Stopping VM: $VM${RESET}"
    multipass stop "$VM"
  done
  echo -e "${GREEN}✅ All VMs have been stopped.${RESET}"
  exit 0
}

# Cleanup all VMs managed by Multipass
function cleanup_vms() {
  echo -e "${CYAN}🧹 Cleaning up all VMs managed by Multipass...${RESET}"
  if [[ -f "scripts/cleanup.sh" ]]; then
    chmod +x scripts/cleanup.sh
    ./scripts/cleanup.sh
  else
    echo -e "${RED}Error: cleanup.sh not found in the scripts folder!${RESET}"
    exit 1
  fi
}

# Main script execution
function main() {
  # Parse command-line arguments
  if [[ "$1" == "--help" ]]; then
    display_help
  elif [[ "$1" == "--shutdown" ]]; then
    check_config_file
    load_config
    shutdown_vms
  elif [[ "$1" == "--cleanup" ]]; then
    cleanup_vms
  fi

  run_prerequisites
  check_config_file
  ensure_base_domain
  load_config
  get_current_vms
  echo -e "${CYAN}🔄 Reconciling VM pool with config.json...${RESET}"
  remove_unwanted_vms
  ensure_ssh_keys
  reconcile_vms
  generate_inventory
  update_local_hosts
  update_vm_hosts
  apply_ansible_playbook
  display_vm_details
}

main "$@"
