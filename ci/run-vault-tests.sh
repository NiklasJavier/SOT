#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=./setup-env.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/setup-env.sh"

VAULT_SCRIPT="$ROOT_DIR/scripts/core/vault.sh"

# shellcheck disable=SC2154
OUTPUT=$(PATH="$PATH" bash "$VAULT_SCRIPT" placeholder placeholder placeholder "$vault_file" "$vault_secret" 2>&1)
if ! grep -q "The Vault file" <<<"$OUTPUT"; then
  echo "Vault script did not acknowledge the expected vault file" >&2
  echo "$OUTPUT"
  exit 1
fi

if ! grep -q "Temporary access file" <<<"$OUTPUT"; then
  echo "Vault script did not create the temporary password file" >&2
  echo "$OUTPUT"
  exit 1
fi

echo "Vault workflow smoke test completed successfully."
