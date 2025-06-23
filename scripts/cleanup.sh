#!/bin/bash

# warning: this script will delete only VMs defined in the config.json file

CONFIG_FILE="../config.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: $CONFIG_FILE not found!"
  exit 1
fi

# Extract VM names from config.json
VM_NAMES=$(jq -r '.vms[].name' "$CONFIG_FILE")

if [[ -z "$VM_NAMES" ]]; then
  echo "No VMs found in $CONFIG_FILE."
  exit 0
fi

# Delete each VM
for VM in $VM_NAMES; do
  echo "Deleting VM: $VM"
  multipass delete "$VM"
done

# Purge deleted VMs
multipass purge

# Clean up cloud-init files
rm -Rvf cloud-init/*