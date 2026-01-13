#!/usr/bin/env bash
#
# SOT Cleanup Old Users Script
# Entfernt alte Test-Benutzer und bereinigt UFW-Regeln
#
set -euo pipefail

# =============================================================================
# Bibliothek laden
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ -f "$SCRIPT_ROOT/lib/init.sh" ]]; then
    source "$SCRIPT_ROOT/lib/init.sh"
else
    # Fallback falls lib nicht verfügbar
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    PINK='\033[0;35m'
    GREY='\033[1;90m'
    NC='\033[0m'
fi

# =============================================================================
# Parameter
# =============================================================================
currentUsername="${3:-}"

# =============================================================================
# Funktionen
# =============================================================================

issueReturnRequestToWork() {
    echo -e "${RED}⚠️  This script will delete all ports not listed in the SSH configuration and all folders not present in the config.yml file.${NC}"
    echo -e "${RED}    Please ensure the current directory is listed in the config.yml file, or these files will be permanently deleted.${NC}"

    read -r -p "Do you wish to proceed? (yes/no): " confirmation

    if [[ "$confirmation" != "yes" ]]; then
        echo -e "${RED}Operation aborted. No changes were made.${NC}"
        exit 1
    fi
}

findAndDeleteOldUsers() {
    echo -e "${GREY}Extracting user names from the home directory.${NC}"
    
    while IFS= read -r -d '' dir; do
        username=$(basename "$dir")
        echo -e "${GREY}>> Extracted user name: ${YELLOW}$username${NC}"
        
        # Add the user name to the list if it is not the currentUsername
        if [[ "$username" != "$currentUsername" ]]; then
            echo -e "${RED}The user ${YELLOW}$username ${RED}will be deleted.${NC}"
            srv_dir="/opt/SRV-$username"
            echo -e "${GREY}Extracted service directory: ${YELLOW}$srv_dir${NC}"
            home_dir="/home/$username"
            
            sudo userdel -r "$username" 2>/dev/null || true
            sudo rm -rf "$srv_dir" 2>/dev/null || true
            sudo rm -rf "$home_dir" 2>/dev/null || true
        else
            echo -e "${GREY}The user ${YELLOW}$username ${GREY}is the ${GREEN}current ${GREY}user and will not be deleted.${NC}"
        fi
    done < <(find /home -regextype posix-extended -maxdepth 1 -mindepth 1 -type d -regex '.*/[A-Z]{11}' -print0 2>/dev/null)
}

checkSSHPortAndCleanUFWRules() {
    # Step 1: Extract the SSH port from the configuration file
    local ssh_port
    ssh_port=$(grep "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    
    # If no port is explicitly set in the file, use default port 22
    if [[ -z "$ssh_port" ]]; then
        ssh_port=22
        echo -e "${YELLOW}No SSH port was found in the configuration file. Using default port 22.${NC}"
    fi
    echo -e "${GREY}>> Extracted SSH port: ${YELLOW}$ssh_port${NC}"
    
    # Step 2: List of open ports with ufw
    local open_ports
    open_ports=$(sudo ufw status numbered 2>/dev/null | grep -oP '\d+(?=/tcp)' || true)
    
    # Step 3: Remove rules for unused ports
    echo -e "${GREY}If the same port is specified twice, this means 1x IPV4 and 1x IPV6 for the same port as a rule.${NC}"
    
    for port in $open_ports; do
        if [[ "$port" -ne "$ssh_port" ]]; then
            echo -e "${RED}Port ${YELLOW}$port ${RED}is not the SSH port and will be deleted.${NC}"
            sudo ufw delete allow "$port/tcp" 2>/dev/null || true
        else
            echo -e "${GREY}Port (IPV4/IPV6) ${YELLOW}$port ${GREY}is the SSH port and will not be deleted.${NC}"
        fi
    done
}

# =============================================================================
# Hauptprogramm
# =============================================================================

methods=(
    issueReturnRequestToWork
    findAndDeleteOldUsers
    checkSSHPortAndCleanUFWRules
)

for method in "${methods[@]}"; do
    echo -e "\n${GREY}======= ${GREEN}Running: ${PINK}[$method] ${GREY}=======${NC}"
    $method
done
