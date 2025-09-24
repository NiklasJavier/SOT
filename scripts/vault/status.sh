#!/bin/bash

set -euo pipefail

APPENDED_ARGS_COUNT=10
if [[ $# -lt ${APPENDED_ARGS_COUNT} ]]; then
  echo "vault status: expected CLI metadata arguments from SOT. Please invoke via 'SOT vault status'." >&2
  exit 1
fi

args=("$@")
META_ARGS=("${args[@]: -${APPENDED_ARGS_COUNT}}")

vault_file="${META_ARGS[3]}"
vault_secret="${META_ARGS[4]}"

GREY='\033[1;90m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [[ -z "$vault_file" ]]; then
  echo -e "${RED}No vault_file configured. Aborting.${NC}" >&2
  exit 1
fi

echo -e "${GREY}Vault file: ${YELLOW}$vault_file${NC}"

if [[ ! -f "$vault_file" ]]; then
  echo -e "${RED}  ✗ File does not exist.${NC}"
  exit 1
fi

echo -e "${GREEN}  ✓ File exists.${NC}"

first_line=$(head -n 1 "$vault_file" 2>/dev/null || true)
if [[ "$first_line" == *"ANSIBLE_VAULT"* ]]; then
  echo -e "${GREEN}  ✓ File appears to be Ansible Vault encrypted.${NC}"
else
  echo -e "${YELLOW}  ! File does not look like an Ansible Vault file.${NC}"
fi

if ! command -v ansible-vault >/dev/null 2>&1; then
  echo -e "${YELLOW}  ! ansible-vault command not available — skipping password verification.${NC}"
  exit 0
fi

PASS_FILE=$(mktemp)
trap 'rm -f "$PASS_FILE"' EXIT
printf '%s' "$vault_secret" > "$PASS_FILE"
chmod 600 "$PASS_FILE"

if ansible-vault view --vault-password-file="$PASS_FILE" "$vault_file" >/dev/null 2>&1; then
  echo -e "${GREEN}  ✓ Vault secret works for this file.${NC}"
else
  echo -e "${RED}  ✗ Provided vault_secret could not decrypt the file.${NC}"
  exit 1
fi
