#!/bin/bash

set -euo pipefail

APPENDED_ARGS_COUNT=10
if [[ $# -lt ${APPENDED_ARGS_COUNT} ]]; then
  echo "vault open: expected CLI metadata arguments from SOT. Please invoke via 'SOT vault open'." >&2
  exit 1
fi

args=("$@")
META_ARGS=("${args[@]: -${APPENDED_ARGS_COUNT}}")

vault_file="${META_ARGS[3]}"
vault_secret="${META_ARGS[4]}"

GREY='\033[1;90m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ -z "$vault_file" ]]; then
  echo -e "${RED}No vault_file configured. Aborting.${NC}" >&2
  exit 1
fi

if [[ ! -f "$vault_file" ]]; then
  echo -e "${RED}The Vault file ${YELLOW}$vault_file ${RED}does not exist.${NC}"
  exit 1
fi

if ! command -v ansible-vault >/dev/null 2>&1; then
  echo -e "${RED}ansible-vault is required to open the Vault file.${NC}" >&2
  exit 1
fi

PASS_FILE=$(mktemp)
trap 'rm -f "$PASS_FILE"' EXIT
printf '%s' "$vault_secret" > "$PASS_FILE"
chmod 600 "$PASS_FILE"

echo -e "${GREY}Using temporary access file ${YELLOW}$PASS_FILE${GREY}.${NC}"

if ansible-vault edit --vault-password-file="$PASS_FILE" "$vault_file"; then
  echo -e "${GREEN}The Vault file ${YELLOW}$vault_file${GREEN} was successfully opened.${NC}"
else
  echo -e "${RED}The Vault file ${YELLOW}$vault_file${RED} could not be opened.${NC}"
  exit 1
fi
