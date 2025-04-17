#!/bin/bash

# Colors
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RESET='\033[0m'

# Cleanup all VMs managed by Multipass
function cleanup_vms() {
  echo -e "${CYAN}🧹 Cleaning up all VMs managed by Multipass...${RESET}"
  for VM in $(multipass list --format json | jq -r '.list[].name'); do
    echo -e "${YELLOW}Deleting VM: $VM${RESET}"
    multipass delete "$VM"
  done
  multipass purge
  echo -e "${GREEN}✅ All VMs have been cleaned up.${RESET}"
}

cleanup_vms