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
done < <(printf '%s\n' "$TOOLS")

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

# =============================================================================
# Tool Installation mit Progress-Anzeige
# =============================================================================

# Zähle zu installierende Tools
TOOL_COUNT=1  # SDKMAN ist immer dabei
[[ "$TOOLS" =~ (^|[[:space:]])docker([[:space:]]|$) ]] && ((++TOOL_COUNT))
[[ "$TOOLS" =~ (^|[[:space:]])ansible([[:space:]]|$) ]] && ((++TOOL_COUNT))
TOOL_CURRENT=0

# Progress-Funktion
show_tool_progress() {
    local current="$1"
    local total="$2"
    local label="$3"
    local percent=$((current * 100 / total))
    local filled=$((percent * 25 / 100))
    local empty=$((25 - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    printf "  ${GREEN}[%s]${NC} %3d%% %s\n" "$bar" "$percent" "$label"
}

echo ""
echo -e "  ${BOLD}┌────────────────────────────────────────────┐${NC}"
echo -e "  ${BOLD}│${NC}      ${GREEN}Tool Installation${NC}                    ${BOLD}│${NC}"
echo -e "  ${BOLD}└────────────────────────────────────────────┘${NC}"
echo ""

# SDKMAN Installation
((++TOOL_CURRENT))
show_tool_progress "$TOOL_CURRENT" "$TOOL_COUNT" "SDKMAN! wird installiert..."
if [ -f "$MODULES_DIR/sdkman/install.sh" ]; then
    bash "$MODULES_DIR/sdkman/install.sh" "$sdkman_arg" 2>&1 | sed 's/^/    /'
    echo -e "  ${GREEN}✓${NC} SDKMAN! installiert"
else
    echo -e "  ${RED}✗${NC} SDKMAN! Installationsskript nicht gefunden: $MODULES_DIR/sdkman/install.sh"
fi

# Docker Installation
if [[ "$TOOLS" =~ (^|[[:space:]])docker([[:space:]]|$) ]]; then
    ((++TOOL_CURRENT))
    show_tool_progress "$TOOL_CURRENT" "$TOOL_COUNT" "Docker wird installiert..."
    if [ -f "$MODULES_DIR/docker/install.sh" ]; then
        bash "$MODULES_DIR/docker/install.sh" 2>&1 | sed 's/^/    /'
        echo -e "  ${GREEN}✓${NC} Docker installiert"
    else
        echo -e "  ${RED}✗${NC} Docker Installationsskript nicht gefunden: $MODULES_DIR/docker/install.sh"
    fi
fi

# Ansible Installation
if [[ "$TOOLS" =~ (^|[[:space:]])ansible([[:space:]]|$) ]]; then
    ((++TOOL_CURRENT))
    show_tool_progress "$TOOL_CURRENT" "$TOOL_COUNT" "Ansible wird installiert..."
    if [ -f "$MODULES_DIR/ansible/install.sh" ]; then
        bash "$MODULES_DIR/ansible/install.sh" 2>&1 | sed 's/^/    /'
        echo -e "  ${GREEN}✓${NC} Ansible installiert"
    else
        echo -e "  ${RED}✗${NC} Ansible Installationsskript nicht gefunden: $MODULES_DIR/ansible/install.sh"
    fi
fi

echo ""
echo -e "  ${GREEN}✓ Tool-Installation abgeschlossen${NC}"