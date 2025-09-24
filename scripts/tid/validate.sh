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
if ! CONFIG_FILE_PATH=$(find_config_file_arg "$@"); then
  echo -e "${RED}config.yaml not found in provided arguments. Aborting.${NC}"
  exit 1
fi

SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CONFIG_LOADER="$SCRIPT_ROOT/setup/config_loader.py"

if [[ ! -x "$CONFIG_LOADER" ]]; then
  if [[ -f "$CONFIG_LOADER" ]]; then
    chmod +x "$CONFIG_LOADER" 2>/dev/null || true
  fi
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo -e "${RED}python3 is required to parse $CONFIG_FILE_PATH.${NC}"
  exit 1
fi

while IFS= read -r assignment; do
  [[ -z "$assignment" ]] && continue
  eval "$assignment"
done < <(python3 "$CONFIG_LOADER" "$CONFIG_FILE_PATH" --select tid_enabled tid_dir tid_branch)

TID_ENABLED=${tid_enabled:-"true"}
TID_DIR=${tid_dir:-"/opt/TID"}
TID_BRANCH=${tid_branch:-"main"}

if ! is_true "$TID_ENABLED"; then
  echo -e "${GREY}TID integration disabled — nothing to validate.${NC}"
  exit 0
fi

echo -e "${GREY}Checking TID repository at ${YELLOW}$TID_DIR${GREY}...${NC}"

status_ok=true

if [[ ! -d "$TID_DIR/.git" ]]; then
  echo -e "${RED}  ✗ No git repository found at $TID_DIR. Run 'SOT tid sync'.${NC}"
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

if $status_ok; then
  echo -e "${GREEN}TID validation successful.${NC}"
else
  echo -e "${RED}TID validation reported issues.${NC}"
  exit 1
fi
