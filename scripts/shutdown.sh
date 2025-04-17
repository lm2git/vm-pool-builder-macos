#!/bin/bash

CONFIG_FILE="../config.json"

# Ensure config.json exists
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

# Stop each VM
for VM in $VM_NAMES; do
  echo "Stopping VM: $VM"
  multipass stop "$VM"
done

echo "All VMs have been stopped."
