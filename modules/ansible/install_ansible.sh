#!/bin/bash
# Farben für die Ausgabe
GREEN='\033[0;32m'
GREY='\033[1;90m'
RED='\033[0;31m'
NC='\033[0m' # Keine Farbe

# Skript zur Installation von Ansible und seinen Abhängigkeiten auf Ubuntu/Debian

# Überprüfen, ob Ansible bereits installiert ist
if command -v ansible &> /dev/null; then
    echo -e "${GREY}Ansible is already installed.${NC}"
else
    echo -e "${GREY}Update the package list and install dependencies..."
    # Update der Paketliste und Installation der Voraussetzungen
    sudo apt-get update
    sudo apt-get install -y \
        software-properties-common 

    # Hinzufügen des Ansible PPA und Installation von Ansible
    echo -e "${GREY}Adding Ansible PPA..."
    sudo apt-add-repository --yes --update ppa:ansible/ansible

    echo -e "${GREY}Installing Ansible..."
    sudo apt-get install -y ansible
    sudo ansible-galaxy collection install community.general

    # Prüfen, ob Ansible installiert wurde
    echo -e "${GREY}Checking if Ansible was installed successfully...${NC}"
    if ansible --version > /dev/null 2>&1; then
        echo -e "${GREY}Ansible installed successfully.${NC}"
    else
        echo -e "${RED}Ansible installation failed.${NC}"
        exit 1
    fi
fi

echo -e "${GREY}Script finished: Ansible installation complete.${NC}"
