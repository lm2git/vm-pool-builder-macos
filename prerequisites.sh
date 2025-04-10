#!/bin/bash

# Funzione per verificare se un comando esiste
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Aggiorna Homebrew
echo "Aggiornamento di Homebrew..."
if ! command_exists brew; then
  echo "Homebrew non trovato. Installazione..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Homebrew è già installato. Aggiornamento..."
  brew update
fi

# Installa Multipass
echo "Installazione di Multipass..."
if ! command_exists multipass; then
  brew install --cask multipass
else
  echo "Multipass è già installato."
fi

# Installa jq (JSON parser)
echo "Installazione di jq..."
if ! command_exists jq; then
  brew install jq
else
  echo "jq è già installato."
fi

# Installa Python3 e pip
echo "Installazione di Python3..."
if ! command_exists python3; then
  brew install python
else
  echo "Python3 è già installato."
fi

# Installa Ansible
echo "Installazione di Ansible..."
if ! command_exists ansible; then
  brew install ansible
else
  echo "Ansible è già installato."
fi

# Installa Git (se non è già installato)
echo "Installazione di Git..."
if ! command_exists git; then
  brew install git
else
  echo "Git è già installato."
fi

# Genera la chiave SSH
echo "Generazione della chiave SSH..."
mkdir -p ssh_keys
ssh-keygen -t rsa -b 4096 -f ssh_keys/id_rsa -N ""



# Verifica se tutte le dipendenze sono state installate correttamente
echo "Verifica delle installazioni:"
echo "Multipass: $(command_exists multipass && echo 'OK' || echo 'KO')"
echo "jq: $(command_exists jq && echo 'OK' || echo 'KO')"
echo "Python3: $(command_exists python3 && echo 'OK' || echo 'KO')"
echo "Ansible: $(command_exists ansible && echo 'OK' || echo 'KO')"
echo "Git: $(command_exists git && echo 'OK' || echo 'KO')"

echo "Installa tutte le dipendenze per il progetto completata!"
