#!/usr/bin/env bash

# Load shared library
SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/init.sh
source "$SCRIPT_ROOT/lib/init.sh"

modules_dir="$1"
config_file="$2"

playbook_name="host_setup" # Name des Ansible Playbooks -> playbookname bspw. (local_setup).yml
inventory_key="default"    # Inventarordner (z.B. default, container)

ansibleOpenPlaybook() {
  bash "$modules_dir/ansible/trigger_playbook.sh" \
    "$modules_dir" \
    "$config_file" \
    "$playbook_name" \
    "$inventory_key"
}

methods=(
  ansibleOpenPlaybook
)

for method in "${methods[@]}"; do
  echo -e "\n${GREY}======= ${GREEN}Running: ${PINK}[$method] ${GREY}=======${NC}"
  "$method"
done
