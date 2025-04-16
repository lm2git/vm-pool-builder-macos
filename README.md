# 🚀 VM Pool Builder (for macOS)

This repository automates the creation and configuration of a pool of virtual machines (VMs) using **Multipass** on macOS. It handles everything from prerequisites installation to VM provisioning and configuration using **Ansible**.

---

## ✨ Features

- ✅ **Automated Dependency Installation**: Homebrew, Multipass, jq, Python3, Ansible, Git.
- ✅ **VM Pool Reconciliation**: Ensures the VM pool matches the desired state defined in `config.json`:
  - Removes VMs not listed in `config.json`.
  - Adds or updates VMs to match the desired specifications.
- ✅ **Cloud-Init Support**: Automatically regenerates cloud-init configurations for each VM.
- ✅ **Ansible Integration**: Auto-generates inventory files and runs playbooks for VM setup.
- ✅ **Secure Access**: SSH key generation for secure VM access.
- ✅ **Enhanced Validation**: 
  - Detects duplicate VM names in `config.json`.
  - Ensures disk values include the "G" unit (e.g., `10G`).
  - Validates the schema of `config.json` for required fields.

---

## 📋 Prerequisites

Ensure your macOS system meets the following requirements:
- macOS **10.15 or later**.
- Active **Internet connection**.

---

## 📂 Repository Structure

```plaintext
/scripts
├── prerequisites.sh       # Installs all required dependencies
├── apply.sh               # Main script to reconcile and configure VMs
├── generate_cloud_init.py # Generates cloud-init files
├── config.json            # Configuration file for VM specifications
├── ansible/
│   └── playbook.yml       # Ansible playbook for VM configuration
└── ssh_keys/              # Directory for generated SSH keys
```

---

## 🚀 Usage

### Step 1: Clone the Repository

```bash
git clone https://github.com/lm2git/vm-pool-builder-macos
cd vm-pool-builder-macos
```

### Step 2: Configure `config.json`

Edit the `config.json` file to define your VM specifications. Example:

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

> **Note**: Ensure the following:
> - VM names are unique.
> - Disk values include the "G" unit (e.g., `10G`).
> - All VMs have `name`, `cpus`, `memory`, and `disk` fields.

### Step 3: Run the Main Script

Make the script executable and run it:

```bash
chmod +x apply.sh && ./apply.sh
```

- The script installs prerequisites if not already installed.
- It reconciles the VM pool:
  - Removes VMs not listed in `config.json`.
  - Adds or updates VMs to match the desired state.
  - Regenerates cloud-init files and `inventory.ini`.
  - Applies Ansible configuration to all VMs.
- After completion, it displays VM details, including IP addresses and SSH commands.

Example output:

```bash
vm1 - IP: 192.168.64.2
   ➤ SSH: ssh -i /path/to/repo/ssh_keys/id_rsa root@192.168.64.2
vm2 - IP: 192.168.64.3
   ➤ SSH: ssh -i /path/to/repo/ssh_keys/id_rsa root@192.168.64.3
```

---

## 🧹 Cleanup Process

If you need to delete the VMs created by this tool, you can use the `apply.sh` script with an empty `vms` array in `config.json`. This will remove all VMs and clean up residual data.

---

## 🛠️ Customize with Ansible

The `ansible/playbook.yml` file is used to configure the VMs. Modify it as needed and re-run the script:

```bash
./apply.sh
```

- The `inventory.ini` file is auto-generated.

---

## 📝 Notes

- The `prerequisites.sh` script ensures all dependencies are installed.
- The `generate_cloud_init.py` script generates cloud-init YAML files for each VM based on `config.json`.
- SSH keys are stored in the `ssh_keys/` directory for secure access.

---

## 🛠️ Troubleshooting

- Ensure **Multipass** is installed and running correctly.
- Verify the `config.json` file is properly formatted.
- Check logs for errors during VM reconciliation or Ansible execution.

---

## 📜 License

This project is licensed under the **MIT License**. See the `LICENSE` file for details.