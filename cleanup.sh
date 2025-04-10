#!/bin/bash

# warning: this script will delete all VMs created by the create_vms.sh script

multipass delete --all
# Pulisci i dati residui
multipass purge

rm -Rvf cloud-init/*