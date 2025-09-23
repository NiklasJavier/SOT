#!/bin/bash

# aat sync: Synchronize the AAT repository based on values in config.yaml
# This script is invoked via: SOT aat sync
# The SOT CLI appends standard arguments including modules_dir, CONFIG_FILE, username, vault_file, vault_secret, opt_data_dir, clone_dir, systemlink_path, log_file, branch

set -euo pipefail

GREY='\033[1;90m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

BRANCH_OVERRIDE=""
FILTERED_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      shift
      if [[ $# -eq 0 ]]; then
        echo -e "${RED}--branch requires a value.${NC}"
        exit 1
      fi
      BRANCH_OVERRIDE="$1"
      shift
      ;;
    *)
      FILTERED_ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${FILTERED_ARGS[@]}"

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
      aat_repo_url) AAT_REPO_URL="$value" ;;
      aat_dir) AAT_DIR="$value" ;;
      aat_enabled) AAT_ENABLED="$value" ;;
      aat_branch) AAT_BRANCH="$value" ;;
    esac
  fi
done < "$CONFIG_FILE_PATH"

AAT_ENABLED=${AAT_ENABLED:-"true"}
AAT_REPO_URL=${AAT_REPO_URL:-"https://github.com/NiklasJavier/AAT.git"}
AAT_DIR=${AAT_DIR:-"/opt/AAT"}
AAT_BRANCH=${AAT_BRANCH:-"main"}

if [[ -n "$BRANCH_OVERRIDE" ]]; then
  AAT_BRANCH="$BRANCH_OVERRIDE"
fi

if [[ "$AAT_ENABLED" != "true" ]]; then
  echo -e "${GREY}AAT integration disabled (aat_enabled != true). Nothing to do.${NC}"
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo -e "${RED}git is required to sync AAT. Please install git and retry.${NC}"
  exit 1
fi

echo -e "${GREY}Syncing AAT at ${YELLOW}$AAT_DIR${GREY} from ${YELLOW}$AAT_REPO_URL${GREY} (branch ${YELLOW}$AAT_BRANCH${GREY})...${NC}"
mkdir -p "$AAT_DIR"
if [[ -d "$AAT_DIR/.git" ]]; then
  if ! git -C "$AAT_DIR" fetch origin "$AAT_BRANCH"; then
    echo -e "${YELLOW}Warning: 'git fetch' failed. Removing local repository for a clean clone...${NC}"
    rm -rf "$AAT_DIR"
  else
    if ! git -C "$AAT_DIR" checkout "$AAT_BRANCH" >/dev/null 2>&1; then
      echo -e "${YELLOW}Warning: branch '$AAT_BRANCH' is unavailable locally. Re-cloning...${NC}"
      rm -rf "$AAT_DIR"
    elif ! git -C "$AAT_DIR" pull --ff-only origin "$AAT_BRANCH"; then
      echo -e "${YELLOW}Warning: 'git pull' failed. Re-cloning repository...${NC}"
      rm -rf "$AAT_DIR"
    fi
  fi
fi

if [[ ! -d "$AAT_DIR/.git" ]]; then
  rm -rf "$AAT_DIR"
  if ! git clone --depth 1 --single-branch --branch "$AAT_BRANCH" "$AAT_REPO_URL" "$AAT_DIR"; then
    echo -e "${RED}Failed to clone AAT repository.${NC}"
    exit 1
  fi
fi

echo -e "${GREY}AAT sync completed.${NC}"


