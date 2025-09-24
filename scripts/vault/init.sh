#!/bin/bash

set -euo pipefail

APPENDED_ARGS_COUNT=10
if [[ $# -lt ${APPENDED_ARGS_COUNT} ]]; then
  echo "vault init: expected CLI metadata arguments from SOT. Please invoke via 'SOT vault init'." >&2
  exit 1
fi

args=("$@")
META_ARGS=("${args[@]: -${APPENDED_ARGS_COUNT}}")

modules_dir="${META_ARGS[0]}"
config_file="${META_ARGS[1]}"
username="${META_ARGS[2]}"
vault_file="${META_ARGS[3]}"
vault_secret="${META_ARGS[4]}"
opt_data_dir="${META_ARGS[5]}"
clone_dir="${META_ARGS[6]}"

GREY='\033[1;90m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [[ -z "$vault_file" ]]; then
  echo -e "${RED}No vault_file configured. Aborting.${NC}" >&2
  exit 1
fi

if [[ -f "$vault_file" ]]; then
  echo -e "${YELLOW}Vault file ${vault_file} already exists — nothing to do.${NC}"
  exit 0
fi

if ! command -v ansible-vault >/dev/null 2>&1; then
  echo -e "${RED}ansible-vault is required to initialise the Vault file.${NC}" >&2
  exit 1
fi

vault_dir=$(dirname "$vault_file")
mkdir -p "$vault_dir"

template_candidates=(
  "$clone_dir/setup/vault_template.j2"
  "$modules_dir/setup/vault_template.j2"
  "$(dirname "$config_file")/vault_template.j2"
)

template=""
for candidate in "${template_candidates[@]}"; do
  if [[ -f "$candidate" ]]; then
    template="$candidate"
    break
  fi
fi

if [[ -z "$template" ]]; then
  echo -e "${YELLOW}No vault template found. Creating an empty Vault file.${NC}"
  printf '# Ansible Vault file initialised by SOT for %s\n' "$username" > "$vault_file"
else
  cp "$template" "$vault_file"
fi

PASS_FILE=$(mktemp)
trap 'rm -f "$PASS_FILE"' EXIT
printf '%s' "$vault_secret" > "$PASS_FILE"
chmod 600 "$PASS_FILE"

if ansible-vault encrypt --vault-password-file="$PASS_FILE" "$vault_file" >/dev/null 2>&1; then
  chmod 600 "$vault_file"
  echo -e "${GREEN}Vault file initialised at ${YELLOW}$vault_file${GREEN}.${NC}"
else
  echo -e "${RED}Failed to encrypt the Vault file.${NC}" >&2
  exit 1
fi
