#!/bin/bash

set -euo pipefail

GREY='\033[1;90m'
GREEN='\033[0;32m'
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

is_true() {
  case "${1,,}" in
    true|1|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

CONFIG_FILE_PATH=""
if CONFIG_FILE_PATH=$(find_config_file_arg "$@"); then
  :
else
  echo -e "${RED}config.yaml not found in provided arguments. Aborting.${NC}"
  exit 1
fi

while IFS= read -r line; do
  line="${line%%#*}"
  line="${line%%$'\r'}"
  [[ -z "${line//[[:space:]]/}" ]] && continue
  if [[ "$line" == *":"* ]]; then
    key=$(echo "$line" | cut -d ':' -f 1 | xargs)
    value=$(echo "$line" | cut -d ':' -f 2- | xargs)
    value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/')
    case "$key" in
      aat_enabled) AAT_ENABLED="$value" ;;
      aat_dir) AAT_DIR="$value" ;;
      aat_branch) AAT_BRANCH="$value" ;;
      tid_enabled) TID_ENABLED="$value" ;;
      tid_dir) TID_DIR="$value" ;;
      tid_branch) TID_BRANCH="$value" ;;
    esac
  fi
done < "$CONFIG_FILE_PATH"

AAT_ENABLED=${AAT_ENABLED:-"true"}
AAT_DIR=${AAT_DIR:-"/opt/AAT"}
AAT_BRANCH=${AAT_BRANCH:-"main"}
TID_ENABLED=${TID_ENABLED:-"true"}
TID_DIR=${TID_DIR:-"/opt/TID"}
TID_BRANCH=${TID_BRANCH:-"main"}

status_ok=true

echo -e "${GREY}Validating integration state...${NC}"

if is_true "$AAT_ENABLED"; then
  echo -e "${GREY}Checking AAT repository at ${YELLOW}$AAT_DIR${GREY}...${NC}"
  if [[ ! -d "$AAT_DIR/.git" ]]; then
    echo -e "${RED}  ✗ No git repository found at $AAT_DIR. Run 'SOT integrations aat_sync'.${NC}"
    status_ok=false
  else
    current_branch=$(git -C "$AAT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    if [[ "$current_branch" != "$AAT_BRANCH" ]]; then
      echo -e "${YELLOW}  ! Expected branch '$AAT_BRANCH' but repository is on '$current_branch'.${NC}"
      status_ok=false
    fi
    if [[ -f "$AAT_DIR/playbooks/site.yml" || -f "$AAT_DIR/ansible/playbooks/site.yml" ]]; then
      echo -e "${GREEN}  ✓ Required playbook found.${NC}"
    else
      echo -e "${RED}  ✗ Expected playbook 'playbooks/site.yml' not found in AAT repository.${NC}"
      status_ok=false
    fi
  fi
else
  echo -e "${GREY}AAT integration disabled — skipping.${NC}"
fi

echo
if is_true "$TID_ENABLED"; then
  echo -e "${GREY}Checking TID repository at ${YELLOW}$TID_DIR${GREY}...${NC}"
  if [[ ! -d "$TID_DIR/.git" ]]; then
    echo -e "${RED}  ✗ No git repository found at $TID_DIR. Run 'SOT integrations tid_sync'.${NC}"
    status_ok=false
  else
    current_branch=$(git -C "$TID_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    if [[ "$current_branch" != "$TID_BRANCH" ]]; then
      echo -e "${YELLOW}  ! Expected branch '$TID_BRANCH' but repository is on '$current_branch'.${NC}"
      status_ok=false
    fi
    if [[ -f "$TID_DIR/modules/proxmox/main.tf" ]]; then
      echo -e "${GREEN}  ✓ Required Terraform module found.${NC}"
    else
      echo -e "${RED}  ✗ Expected module 'modules/proxmox/main.tf' not found in TID repository.${NC}"
      status_ok=false
    fi
  fi
else
  echo -e "${GREY}TID integration disabled — skipping.${NC}"
fi

echo
if $status_ok; then
  echo -e "${GREEN}All integrations validated successfully.${NC}"
else
  echo -e "${RED}One or more integrations require attention.${NC}"
  exit 1
fi
