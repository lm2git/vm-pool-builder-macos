# VM Pool Builder (for macos)

This repository contains scripts to automate the creation and configuration of a pool of virtual machines (VMs) using Multipass on macOS. The setup includes prerequisites installation, VM provisioning, and configuration using Ansible.

## Features

- Automated installation of required dependencies (Homebrew, Multipass, jq, Python3, Ansible, Git).
- Creation of VMs based on a configuration file (`config.json`).
- Cloud-init configuration for each VM.
- Automatic generation of an Ansible inventory file.
- Ansible playbook execution for VM configuration.
- SSH key generation for secure access to VMs.

## Prerequisites

Ensure you have the following installed on your macOS system:
- macOS 10.15 or later
- Internet connection

## Repository Structure

```
/scripts
├── prerequisites.sh       # Script to install all required dependencies
├── create_vms.sh          # Main script to create and configure VMs
├── generate_cloud_init.py # Python script to generate cloud-init files
├── config.json            # Configuration file for VM specifications
├── ansible/
│   └── playbook.yml       # Ansible playbook for VM configuration
└── ssh_keys/              # Directory for generated SSH keys
```

## Usage

### Step 1: Clone the Repository

```bash
git clone https://github.com/lm2git/vm-pool-builder-macos
cd vm-pool-builder-macos
```

### Step 2: Configure `config.json`

First, edit the `config.json` file to define the VM specifications As Code. 
Example:

```json
{
  "interface": "en0",
  "domain": "example.com",
  "vms": [
    {
      "name": "vm1",
      "cpus": 2,
      "memory": "2G",
      "disk": "10G"
    },
    {
      "name": "vm2",
      "cpus": 4,
      "memory": "4G",
      "disk": "20G"
    }
  ]
}
```

### Step 3: Run the Main Script

Then, execute the `create_vms.sh` script to set up the environment and create VMs:

```bash
chmod +x create_vms.sh
./create_vms.sh
```

You will be prompted to install prerequisites if running the script for the first time.

After the script completes, you will see the details of the created VMs, including their IP addresses and SSH commands. Example:

```bash
vm1 - IP: 192.168.64.2
   ➤ SSH: ssh -i /path/to/repo/ssh_keys/id_rsa root@192.168.64.2
vm2 - IP: 192.168.64.3
   ➤ SSH: ssh -i /path/to/repo/ssh_keys/id_rsa root@192.168.64.3
```

### Customize with Ansible

The `ansible/playbook.yml` file is used to configure hosts for the VMs. 
Modify it as needed and re-run the playbook:

The  `inventory.ini` file is auto-generated. 

```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini ansible/playbook.yml
```

## Notes

- The `prerequisites.sh` script ensures all dependencies are installed.
- The `generate_cloud_init.py` script generates cloud-init YAML files for each VM based on `config.json`.
- SSH keys are stored in the `ssh_keys/` directory for secure access.
- The Ansible `inventory.ini` file is auto-generated. 

## Troubleshooting

- Ensure Multipass is installed and running correctly.
- Verify the `config.json` file is properly formatted.
- Check the logs for errors during VM creation or Ansible execution.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.