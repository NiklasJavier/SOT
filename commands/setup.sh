#!/usr/bin/env bash
# =============================================================================
# @cmd: setup
# @category: system
# @description: Server-Konfiguration mit Ansible ausführen
# @usage: SOT setup [--check] [--tags <tags>]
# @example: SOT setup --tags ssh,firewall
# =============================================================================
## Führt das host_setup.yml Playbook aus um den Server zu konfigurieren.
## Unterstützt Ansible Dry-Run (--check) und Tag-Filterung (--tags).
## Konfiguration wird aus der YAML-Config geladen.
# =============================================================================

# Load shared library
SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/init.sh
source "$SCRIPT_ROOT/lib/init.sh"

modules_dir="$1"
config_file="$2"

playbook_name="host_setup" # Name des Ansible Playbooks -> playbookname bspw. (local_setup).yml
inventory_key="default"    # Inventarordner (z.B. default, container)

ansibleOpenPlaybook() {
  bash "$modules_dir/ansible/commands/trigger.sh" \
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
