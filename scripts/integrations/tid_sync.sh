#!/bin/bash

# tid sync: Synchronize the TID (Terraform Infrastructure Deployment) repository
# Usage via SOT: SOT tid sync

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
      tid_repo_url) TID_REPO_URL="$value" ;;
      tid_dir) TID_DIR="$value" ;;
      tid_enabled) TID_ENABLED="$value" ;;
      tid_branch) TID_BRANCH="$value" ;;
    esac
  fi
done < "$CONFIG_FILE_PATH"

TID_ENABLED=${TID_ENABLED:-"true"}
TID_REPO_URL=${TID_REPO_URL:-"https://github.com/NiklasJavier/TID.git"}
TID_DIR=${TID_DIR:-"/opt/TID"}
TID_BRANCH=${TID_BRANCH:-"main"}

if [[ -n "$BRANCH_OVERRIDE" ]]; then
  TID_BRANCH="$BRANCH_OVERRIDE"
fi

if [[ "$TID_ENABLED" != "true" ]]; then
  echo -e "${GREY}TID integration disabled (tid_enabled != true). Nothing to do.${NC}"
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo -e "${RED}git is required to sync TID. Please install git and retry.${NC}"
  exit 1
fi

echo -e "${GREY}Syncing TID at ${YELLOW}$TID_DIR${GREY} from ${YELLOW}$TID_REPO_URL${GREY} (branch ${YELLOW}$TID_BRANCH${GREY})...${NC}"
mkdir -p "$TID_DIR"
if [[ -d "$TID_DIR/.git" ]]; then
  if ! git -C "$TID_DIR" fetch origin "$TID_BRANCH"; then
    echo -e "${YELLOW}Warning: 'git fetch' failed. Removing local repository for a clean clone...${NC}"
    rm -rf "$TID_DIR"
  else
    if ! git -C "$TID_DIR" checkout "$TID_BRANCH" >/dev/null 2>&1; then
      echo -e "${YELLOW}Warning: branch '$TID_BRANCH' is unavailable locally. Re-cloning...${NC}"
      rm -rf "$TID_DIR"
    elif ! git -C "$TID_DIR" pull --ff-only origin "$TID_BRANCH"; then
      echo -e "${YELLOW}Warning: 'git pull' failed. Re-cloning repository...${NC}"
      rm -rf "$TID_DIR"
    fi
  fi
fi

if [[ ! -d "$TID_DIR/.git" ]]; then
  rm -rf "$TID_DIR"
  if ! git clone --depth 1 --single-branch --branch "$TID_BRANCH" "$TID_REPO_URL" "$TID_DIR"; then
    echo -e "${RED}Failed to clone TID repository.${NC}"
    exit 1
  fi
fi

echo -e "${GREY}TID sync completed.${NC}"


