#!/bin/bash

# Farben für die Ausgabe
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Keine Farbe

# Variablen zuweisen
tools_dir="$1"      # Tools-Verzeichnis
config_file="$2"    # Konfigurationsdatei
ansibleName="$3"    # Name des Ansible Playbooks -> playbookname bspw. (local_setup).yml
ansibleFolder="$4"  # Ordner, in dem das Playbook liegt -> playbookfolder bspw. (local)

start_playbook() {
    local playbookname=$1
    local playbookfolder=$2
    echo -e "${GREEN}Running Ansible ${playbookfolder}/${playbookname}...${NC}"
    ANSIBLE_CONFIG="$tools_dir/ansible/${playbookfolder}/ansible.cfg" \
        ansible-playbook \
        -i "$tools_dir/ansible/${playbookfolder}/hosts.ini" \
        "$tools_dir/ansible/${playbookfolder}/playbooks/${playbookname}" \
        --extra-vars "CONFIG_YAML=$config_file"
}

# Sicherstellen, dass ansible-playbook verfügbar ist
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}Ansible ist nicht installiert. Führe Installationsskript aus...${NC}"
    if [ -x "$tools_dir/ansible/install_ansible.sh" ]; then
        bash "$tools_dir/ansible/install_ansible.sh"
    else
        echo -e "${RED}Installationsskript für Ansible nicht gefunden: $tools_dir/ansible/install_ansible.sh${NC}"
        exit 1
    fi
fi

# Überprüfen, ob Docker installiert ist
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker ist nicht installiert. Führe Installationsskript aus...${NC}"
    if [ -x "$tools_dir/docker/install_docker.sh" ]; then
        bash "$tools_dir/docker/install_docker.sh"
    else
        echo -e "${RED}Docker-Installationsskript nicht gefunden: $tools_dir/docker/install_docker.sh${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Docker ist bereits installiert.${NC}"
fi

start_playbook "$ansibleName.yml" "$ansibleFolder"
