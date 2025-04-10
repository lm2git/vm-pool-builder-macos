#!/bin/bash

# Colori
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# Chiedi se è la prima volta che si lancia lo script
read -p "È la prima volta che lanci questo script? Vuoi installare i prerequisiti? (s/n): " INSTALL_PREREQUISITES
if [[ "$INSTALL_PREREQUISITES" == "s" || "$INSTALL_PREREQUISITES" == "S" ]]; then
  echo -e "${CYAN}🔧 Installazione dei prerequisiti...${RESET}"
  chmod +x prerequisites.sh
  ./prerequisites.sh
fi

# Directory corrente assoluta
SCRIPT_DIR="$(pwd)"

# Carica la configurazione da config.json
INTERFACE=$(jq -r '.interface' config.json)
DOMAIN=$(jq -r '.domain' config.json)

echo -e "${CYAN}🧹 Pulizia VM esistenti...${RESET}"
for VM in $(jq -r '.vms[]' config.json | jq -r '.name'); do
  echo -e "${YELLOW}Creating VM: $VM with Ubuntu 22.04${RESET}"

  if multipass info "$VM" &>/dev/null; then
    echo -e "${CYAN}Deleting existing VM: $VM${RESET}"
    multipass delete "$VM"
  fi
done

multipass purge

echo -e "${CYAN}🚀 Lancio delle VM...${RESET}"
for VM in $(jq -r '.vms[]' config.json | jq -r '.name'); do
  echo -e "${GREEN}Launching VM: $VM${RESET}"
  multipass launch 22.04 --name "$VM" \
    --cpus 2 --memory 2G --disk 35G \
    --cloud-init "cloud-init/$VM.yaml" \
    --timeout 300
done

echo -e "${CYAN}⚙️  Generazione cloud-init e inventory...${RESET}"
python3 generate_cloud_init.py

echo -e "${CYAN}🔧 Configurazione con Ansible...${RESET}"
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini ansible/playbook.yml

# Output finale con i dettagli
echo -e "\n${CYAN}🎉 Tutto pronto! Dettagli delle VM:${RESET}"

multipass list --format json | jq -r '.list[] | select(.state == "Running") | "\(.name) \(.ipv4[0])"' | while read name ip; do
  echo -e "${YELLOW}$name${RESET} - IP: ${GREEN}$ip${RESET}"
  echo -e "   ➤ SSH: ${CYAN}ssh -i ${SCRIPT_DIR}/ssh_keys/id_rsa root@$ip${RESET}"
done

echo -e "\n${GREEN}✅ Setup completato con successo.${RESET}"
