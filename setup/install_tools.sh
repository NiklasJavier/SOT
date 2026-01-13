#!/usr/bin/env bash

set -euo pipefail

# Farben für die Ausgabe
GREEN='\033[0;32m'
GREY='\033[1;90m'
RED='\033[0;31m'
NC='\033[0m' # Keine Farbe

MODULES_DIR="$1"
TOOLS="$2"

echo -e "${GREY}Module directory is: $MODULES_DIR${NC}"
echo -e "${GREY}Selected tools are: $TOOLS${NC}"

sdkman_specs=()
while read -r entry; do
    if [[ $entry == sdkman:* ]]; then
        spec="${entry#sdkman:}"
        IFS=',' read -ra parts <<< "$spec"
        for part in "${parts[@]}"; do
            trimmed="${part//[[:space:]]/}"
            if [[ -n "$trimmed" ]]; then
                sdkman_specs+=("$trimmed")
            fi
        done
    fi
done < <(printf '%s\n' $TOOLS)

if [[ -n "${SDKMAN_DEFAULT_CANDIDATES:-}" ]]; then
    IFS=',' read -ra default_specs <<< "${SDKMAN_DEFAULT_CANDIDATES}"
    for part in "${default_specs[@]}"; do
        trimmed="${part//[[:space:]]/}"
        if [[ -n "$trimmed" ]]; then
            sdkman_specs+=("$trimmed")
        fi
    done
fi

declare -A sdkman_unique=()
unique_sdkman_specs=()
for spec in "${sdkman_specs[@]}"; do
    if [[ -z "${sdkman_unique[$spec]:-}" ]]; then
        sdkman_unique[$spec]=1
        unique_sdkman_specs+=("$spec")
    fi
done

sdkman_arg=""
if (( ${#unique_sdkman_specs[@]} )); then
    sdkman_arg="$(IFS=','; echo "${unique_sdkman_specs[*]}")"
fi

echo -e "${GREY}Ensuring SDKMAN! is installed${NC}"
if [ -f "$MODULES_DIR/sdkman/install_sdkman.sh" ]; then
    bash "$MODULES_DIR/sdkman/install_sdkman.sh" "$sdkman_arg"
else
    echo -e "${RED}SDKMAN! installation script not found: $MODULES_DIR/sdkman/install_sdkman.sh${NC}"
fi

# Überprüfen, welche Tools ausgewählt wurden und die entsprechenden Installationsskripte ausführen

# Docker Installation
if [[ "$TOOLS" =~ (^|[[:space:]])docker([[:space:]]|$) ]]; then
    echo -e "${GREY}Installing Docker...${NC}"
    if [ -f "$MODULES_DIR/docker/install_docker.sh" ]; then
        bash "$MODULES_DIR/docker/install_docker.sh"
    else
        echo -e "${RED}Docker installation script not found: $MODULES_DIR/docker/install_docker.sh${NC}"
    fi
fi

# Ansible Installation
if [[ "$TOOLS" =~ (^|[[:space:]])ansible([[:space:]]|$) ]]; then
    echo -e "${GREY}Installing Ansible...${NC}"
    if [ -f "$MODULES_DIR/ansible/install_ansible.sh" ]; then
        bash "$MODULES_DIR/ansible/install_ansible.sh"
    else
        echo -e "${RED}Ansible installation script not found: $MODULES_DIR/ansible/install_ansible.sh${NC}"
    fi
fi