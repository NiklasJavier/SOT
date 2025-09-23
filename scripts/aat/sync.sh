#!/bin/bash

# aat sync: Synchronize the AAT repository based on values in config.yaml
# This script is invoked via: SOT aat sync
# The SOT CLI appends standard arguments including tools_dir, CONFIG_FILE, username, vault_file, vault_secret, opt_data_dir, clone_dir, systemlink_path, log_file, branch

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

# Minimal YAML reader (key: value) — mirrors environments/devops_cli.sh approach
while IFS= read -r line; do
  if echo "$line" | grep -q ":"; then
    key=$(echo "$line" | cut -d ':' -f 1 | xargs)
    value=$(echo "$line" | cut -d ':' -f 2- | xargs)
    value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/')
    case "$key" in
      aat_repo_url) AAT_REPO_URL="$value" ;;
      aat_dir) AAT_DIR="$value" ;;
      aat_enabled) AAT_ENABLED="$value" ;;
    esac
  fi
done < "$CONFIG_FILE_PATH"

AAT_ENABLED=${AAT_ENABLED:-"true"}
AAT_REPO_URL=${AAT_REPO_URL:-"https://github.com/NiklasJavier/AAT.git"}
AAT_DIR=${AAT_DIR:-"/opt/AAT"}

if [[ "$AAT_ENABLED" != "true" ]]; then
  echo -e "${GREY}AAT integration disabled (aat_enabled != true). Nothing to do.${NC}"
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo -e "${RED}git is required to sync AAT. Please install git and retry.${NC}"
  exit 1
fi

echo -e "${GREY}Syncing AAT at ${YELLOW}$AAT_DIR${GREY} from ${YELLOW}$AAT_REPO_URL${GREY}...${NC}"
mkdir -p "$AAT_DIR"
if [ -d "$AAT_DIR/.git" ]; then
  git -C "$AAT_DIR" pull || {
    echo -e "${YELLOW}Warning: 'git pull' failed. Attempting to reclone...${NC}"
    rm -rf "$AAT_DIR/.git" || true
    git clone --depth 1 "$AAT_REPO_URL" "$AAT_DIR" || {
      echo -e "${RED}Failed to sync AAT repository.${NC}"
      exit 1
    }
  }
else
  git clone --depth 1 "$AAT_REPO_URL" "$AAT_DIR" || {
    echo -e "${RED}Failed to clone AAT repository.${NC}"
    exit 1
  }
fi

echo -e "${GREY}AAT sync completed.${NC}"


