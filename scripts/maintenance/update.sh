#!/usr/bin/env bash
#
# SOT Update Script
# Aktualisiert das lokale SOT-Repository
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
    YELLOW='\033[1;33m'
    PINK='\033[0;35m'
    GREY='\033[1;90m'
    NC='\033[0m'
fi

# =============================================================================
# Parameter
# =============================================================================
clone_dir="${7:-$SCRIPT_ROOT}"
branch="${10:-main}"

# =============================================================================
# Funktionen
# =============================================================================

gitOpenLocalRepository() {
    echo -e "${GREY}Current branch: ${YELLOW}$branch${NC}"
    echo -e "${GREY}Current directory: ${YELLOW}$clone_dir${NC}"
    cd "$clone_dir" || {
        err "Error: Could not find the directory $clone_dir."
        exit 1
    }
}

gitFetchAddedContent() {
    echo -e "${GREY}Fetching added content.${NC}"
    echo -e "${YELLOW}>> GIT FETCH <<${NC}"
    if ! timeout 60 git fetch; then
        err "Git fetch timed out or failed"
        exit 1
    fi
}

gitPullNewContentFromBranch() {
    echo -e "${GREY}Pulling new content from branch.${NC}"
    echo -e "${YELLOW}>> GIT PULL --REBASE --AUTOSTASH <<${NC}"
    if ! timeout 120 git pull --rebase --autostash; then
        err "Git pull timed out or failed"
        exit 1
    fi
    echo -e "${GREEN}Successfully pulled new content from branch.${NC}"
}

# =============================================================================
# Hauptprogramm
# =============================================================================

methods=(
    gitOpenLocalRepository
    gitFetchAddedContent
    gitPullNewContentFromBranch
)

for method in "${methods[@]}"; do
    echo -e "\n${GREY}======= ${GREEN}Running: ${PINK}[$method] ${GREY}=======${NC}"
    $method
done
