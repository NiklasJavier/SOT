#!/usr/bin/env bash

# Load shared library
SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../../lib/init.sh
source "$SCRIPT_ROOT/lib/init.sh"

modules_dir="$1"      # Modul-Verzeichnis
config_file="$2"       # Konfigurationsdatei
playbook_name="$3"     # Basisname des Playbooks (ohne .yml)
inventory_key="${4:-default}" # Inventarordner (z.B. default, container)

ANSIBLE_ROOT="$modules_dir/ansible"
PLAYBOOK_PATH="$ANSIBLE_ROOT/playbooks/${playbook_name}.yml"
DEFAULT_CFG="$ANSIBLE_ROOT/ansible.cfg"
DEFAULT_INVENTORY="$ANSIBLE_ROOT/inventory/hosts.ini"
SPECIFIC_CFG="$ANSIBLE_ROOT/inventory/$inventory_key/ansible.cfg"
SPECIFIC_INVENTORY="$ANSIBLE_ROOT/inventory/$inventory_key/hosts.ini"

resolve_inventory() {
    local cfg="$DEFAULT_CFG"
    local inventory="$DEFAULT_INVENTORY"

    if [[ "$inventory_key" != "default" ]]; then
        [[ -f "$SPECIFIC_CFG" ]] && cfg="$SPECIFIC_CFG"
        [[ -f "$SPECIFIC_INVENTORY" ]] && inventory="$SPECIFIC_INVENTORY"
    fi

    if [[ ! -f "$cfg" ]]; then
        echo -e "${RED}Ansible-Konfiguration nicht gefunden: ${YELLOW}$cfg${NC}"
        return 1
    fi

    if [[ ! -f "$inventory" ]]; then
        echo -e "${RED}Inventardatei nicht gefunden: ${YELLOW}$inventory${NC}"
        return 1
    fi

    ANSIBLE_CONFIG="$cfg" ansible-playbook \
        -i "$inventory" \
        "$PLAYBOOK_PATH" \
        --extra-vars "CONFIG_YAML=$config_file"
}

# Sicherstellen, dass ansible-playbook verfügbar ist
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${YELLOW}Ansible ist nicht installiert. Führe Installationsskript aus...${NC}"
    if [ -x "$ANSIBLE_ROOT/install.sh" ]; then
        bash "$ANSIBLE_ROOT/install.sh"
    else
        echo -e "${RED}Installationsskript für Ansible nicht gefunden: ${YELLOW}$ANSIBLE_ROOT/install.sh${NC}"
        exit 1
    fi
fi

# Überprüfen, ob Docker installiert ist
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker ist nicht installiert. Führe Installationsskript aus...${NC}"
    if [ -x "$modules_dir/docker/install.sh" ]; then
        bash "$modules_dir/docker/install.sh"
    else
        echo -e "${RED}Docker-Installationsskript nicht gefunden: ${YELLOW}$modules_dir/docker/install.sh${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Docker ist bereits installiert.${NC}"
fi

if [[ ! -f "$PLAYBOOK_PATH" ]]; then
    echo -e "${RED}Playbook nicht gefunden: ${YELLOW}$PLAYBOOK_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}Running Ansible ${inventory_key}/${playbook_name}.yml...${NC}"
if ! resolve_inventory; then
    exit 1
fi
