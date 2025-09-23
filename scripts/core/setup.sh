#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
PINK='\033[0;35m'
GREY='\033[1;90m'
NC='\033[0m'

tools_dir="$1"
config_file="$2"

ansibleName="host_setup" # Name des Ansible Playbooks -> playbookname bspw. (local_setup).yml
ansibleFolder="host"    # Ordner, in dem das Playbook liegt -> playbookfolder bspw. (local)

ansibleOpenPlaybook() {
bash "$tools_dir/ansible/trigger_playbook.sh" "$tools_dir" "$config_file" "$ansibleName" "$ansibleFolder"
}

methods=(
ansibleOpenPlaybook
)

for method in "${methods[@]}"; do
echo -e "\n${GREY}======= ${GREEN}Running: ${PINK}[$method] ${GREY}=======${NC}"
$method 
done