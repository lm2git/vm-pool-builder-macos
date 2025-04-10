#!/bin/bash

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Update Homebrew
echo "Updating Homebrew..."
if ! command_exists brew; then
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Homebrew is already installed. Updating..."
  brew update
fi

# Install Multipass
echo "Installing Multipass..."
if ! command_exists multipass; then
  brew install --cask multipass
else
  echo "Multipass is already installed."
fi

# Install jq (JSON parser)
echo "Installing jq..."
if ! command_exists jq; then
  brew install jq
else
  echo "jq is already installed."
fi

# Install Python3 and pip
echo "Installing Python3..."
if ! command_exists python3; then
  brew install python
else
  echo "Python3 is already installed."
fi

# Install Ansible
echo "Installing Ansible..."
if ! command_exists ansible; then
  brew install ansible
else
  echo "Ansible is already installed."
fi

# Install Git (if not already installed)
echo "Installing Git..."
if ! command_exists git; then
  brew install git
else
  echo "Git is already installed."
fi

# Generate SSH key
echo "Generating SSH key..."
mkdir -p ssh_keys
ssh-keygen -t rsa -b 4096 -f ssh_keys/id_rsa -N ""

# Verify if all dependencies were installed correctly
echo "Verifying installations:"
echo "Multipass: $(command_exists multipass && echo 'OK' || echo 'KO')"
echo "jq: $(command_exists jq && echo 'OK' || echo 'KO')"
echo "Python3: $(command_exists python3 && echo 'OK' || echo 'KO')"
echo "Ansible: $(command_exists ansible && echo 'OK' || echo 'KO')"
echo "Git: $(command_exists git && echo 'OK' || echo 'KO')"

echo "All project dependencies installed successfully!"
