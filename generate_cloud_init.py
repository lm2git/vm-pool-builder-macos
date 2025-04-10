import json
import os
import subprocess

# Carica il file di configurazione
with open('config.json') as f:
    config = json.load(f)

# Carica la chiave pubblica SSH
with open('ssh_keys/id_rsa.pub') as key_file:
    ssh_key = key_file.read().strip()

# Crea la directory per i file cloud-init
os.makedirs('cloud-init', exist_ok=True)

# Recupera le VM attive e i relativi IP
multipass_info = subprocess.check_output(['multipass', 'list', '--format', 'json'])
instances = json.loads(multipass_info)['list']

# Genera l'inventory.ini per Ansible (solo SSH key, no password)
with open('inventory.ini', 'w') as inventory_file:
    inventory_file.write("[lab]\n")
    for vm in config['vms']:
        name = vm['name']
        # Cerca l'IP assegnato da multipass
        ip = next((i['ipv4'][0] for i in instances if i['name'] == name), None)
        if ip:
            inventory_file.write(f"{name}.{config['domain']} ansible_host={ip} ansible_user=root ansible_ssh_private_key_file=ssh_keys/id_rsa\n")

# Genera i file cloud-init per ogni VM
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

print("Cloud-init files and inventory.ini generated successfully.")
