#!/bin/bash

# tid sync: Synchronize the TID (Terraform Infrastructure Deployment) repository
# Usage via SOT: SOT tid sync

set -euo pipefail

GREY='\033[1;90m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

find_config_file_arg() {
  for arg in "$@"; do
    if [[ -f "$arg" && "$arg" == *"config.yaml"* ]]; then
      echo "$arg"
      return 0
    fi
  done
  return 1
}

CONFIG_FILE_PATH=""
if CONFIG_FILE_PATH=$(find_config_file_arg "$@"); then
  :
else
  echo -e "${RED}config.yaml not found in provided arguments. Aborting.${NC}"
  exit 1
fi

# Minimal YAML reader (key: value) — mirrors setup/cli_wrapper.sh approach
while IFS= read -r line; do
  if echo "$line" | grep -q ":"; then
    key=$(echo "$line" | cut -d ':' -f 1 | xargs)
    value=$(echo "$line" | cut -d ':' -f 2- | xargs)
    value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/')
    case "$key" in
      tid_repo_url) TID_REPO_URL="$value" ;;
      tid_dir) TID_DIR="$value" ;;
      tid_enabled) TID_ENABLED="$value" ;;
    esac
  fi
done < "$CONFIG_FILE_PATH"

TID_ENABLED=${TID_ENABLED:-"true"}
TID_REPO_URL=${TID_REPO_URL:-"https://github.com/NiklasJavier/TID.git"}
TID_DIR=${TID_DIR:-"/opt/TID"}

if [[ "$TID_ENABLED" != "true" ]]; then
  echo -e "${GREY}TID integration disabled (tid_enabled != true). Nothing to do.${NC}"
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo -e "${RED}git is required to sync TID. Please install git and retry.${NC}"
  exit 1
fi

echo -e "${GREY}Syncing TID at ${YELLOW}$TID_DIR${GREY} from ${YELLOW}$TID_REPO_URL${GREY}...${NC}"
mkdir -p "$TID_DIR"
if [ -d "$TID_DIR/.git" ]; then
  git -C "$TID_DIR" pull || {
    echo -e "${YELLOW}Warning: 'git pull' failed. Attempting to reclone...${NC}"
    rm -rf "$TID_DIR/.git" || true
    git clone --depth 1 "$TID_REPO_URL" "$TID_DIR" || {
      echo -e "${RED}Failed to sync TID repository.${NC}"
      exit 1
    }
  }
else
  git clone --depth 1 "$TID_REPO_URL" "$TID_DIR" || {
    echo -e "${RED}Failed to clone TID repository.${NC}"
    exit 1
  }
fi

echo -e "${GREY}TID sync completed.${NC}"


