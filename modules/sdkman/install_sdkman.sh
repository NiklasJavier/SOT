#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
GREY='\033[1;90m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

CANDIDATE_SPEC="${1:-}"
SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"

install_sdkman() {
    if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
        echo -e "${GREY}SDKMAN! already present at ${YELLOW}$SDKMAN_DIR${NC}"
        return
    fi

    echo -e "${GREY}Installing SDKMAN!${NC}"
    if command -v curl >/dev/null 2>&1; then
        curl -s "https://get.sdkman.io" | bash
    else
        echo -e "${RED}curl is required to install SDKMAN!${NC}"
        exit 1
    fi
}

install_candidates() {
    if [[ -z "$CANDIDATE_SPEC" ]]; then
        return
    fi

    # shellcheck disable=SC1090
    source "$SDKMAN_DIR/bin/sdkman-init.sh"

    IFS=',' read -ra requested <<< "$CANDIDATE_SPEC"
    for entry in "${requested[@]}"; do
        [[ -z "$entry" ]] && continue
        name="${entry%%=*}"
        version="${entry#*=}"
        if [[ -z "$name" ]]; then
            continue
        fi

        if [[ "$entry" != *"="* ]]; then
            version=""
        fi

        if [[ -n "$version" && "$version" != "$name" ]]; then
            echo -e "${GREY}Installing ${YELLOW}$name $version${GREY} via SDKMAN!${NC}"
            if ! yes | sdk install "$name" "$version"; then
                echo -e "${RED}Failed to install $name $version via SDKMAN!${NC}"
            fi
        else
            echo -e "${GREY}Installing latest ${YELLOW}$name${GREY} via SDKMAN!${NC}"
            if ! yes | sdk install "$name"; then
                echo -e "${RED}Failed to install $name via SDKMAN!${NC}"
            fi
        fi
    done
}

install_sdkman

if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    install_candidates
else
    echo -e "${RED}SDKMAN! installation failed. Expected init script not found at ${YELLOW}$SDKMAN_DIR/bin/sdkman-init.sh${NC}"
    exit 1
fi
