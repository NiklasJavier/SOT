#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

# shellcheck source=./setup-env.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/setup-env.sh"

if ! command -v bash >/dev/null; then
  echo "bash not found" >&2
  exit 1
fi

CLI_SCRIPT="$ROOT_DIR/environments/sot_cli.sh"

# Basic help output should list available commands.
HELP_OUTPUT=$(CONFIG_FILE="$CONFIG_FILE" bash "$CLI_SCRIPT" help)
if ! grep -q "Available commands" <<<"$HELP_OUTPUT"; then
  echo "CLI help output did not contain expected header" >&2
  echo "$HELP_OUTPUT"
  exit 1
fi

# Asking for help on a specific command should resolve the script and provide a
# deterministic message if no inline help exists.
if ! SPECIFIC_HELP=$(CONFIG_FILE="$CONFIG_FILE" bash "$CLI_SCRIPT" help debug update 2>&1); then
  echo "CLI command specific help invocation failed" >&2
  echo "$SPECIFIC_HELP"
  exit 1
fi

if ! grep -q "No help available for this command" <<<"$SPECIFIC_HELP"; then
  echo "CLI command help did not return the expected fallback message" >&2
  echo "$SPECIFIC_HELP"
  exit 1
fi

echo "CLI smoke tests completed successfully."
