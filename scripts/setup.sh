#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
PINK='\033[0;35m'
GREY='\033[1;90m'
NC='\033[0m'

modules_dir="$1"
config_file="$2"

playbook_name="host_setup" # Name des Ansible Playbooks -> playbookname bspw. (local_setup).yml
inventory_key="default"    # Inventarordner (z.B. default, container)

ansibleOpenPlaybook() {
bash "$modules_dir/ansible/trigger_playbook.sh" "$modules_dir" "$config_file" "$playbook_name" "$inventory_key"
}

methods=(
ansibleOpenPlaybook
)

for method in "${methods[@]}"; do
echo -e "\n${GREY}======= ${GREEN}Running: ${PINK}[$method] ${GREY}=======${NC}"
$method 
done