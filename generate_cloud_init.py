import json
import os
import subprocess

# Load the configuration file
with open('config.json') as f:
    config = json.load(f)

# Load the SSH public key
with open('ssh_keys/id_rsa.pub') as key_file:
    ssh_key = key_file.read().strip()

# Create the directory for cloud-init files
os.makedirs('cloud-init', exist_ok=True)

# Retrieve active VMs and their IPs
multipass_info = subprocess.check_output(['multipass', 'list', '--format', 'json'])
instances = {i['name']: i for i in json.loads(multipass_info)['list']}

# Generate cloud-init files for each VM
for vm in config['vms']:
    cloud_init_content = f"""#cloud-config
users:
  - name: root
    ssh-authorized-keys:
      - {ssh_key}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false

hostname: {vm['name']}.{config['domain']}
manage_etc_hosts: true
"""
    cloud_init_path = f"cloud-init/{vm['name']}.yaml"
    with open(cloud_init_path, 'w') as f:
        f.write(cloud_init_content)

print("Cloud-init files generated successfully.")
