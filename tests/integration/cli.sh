#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

# shellcheck source=./setup-env.sh
# shellcheck disable=SC1091
[[ -f "$SCRIPT_DIR/../setup-env.sh" ]] && source "$SCRIPT_DIR/../setup-env.sh"

if ! command -v bash >/dev/null; then
  echo "bash not found" >&2
  exit 1
fi

CLI_SCRIPT="$ROOT_DIR/bin/sot"

# Basic help output should show usage information
HELP_OUTPUT=$(CONFIG_FILE="${CONFIG_FILE:-$ROOT_DIR/services/default_config.yml}" bash "$CLI_SCRIPT" help)
if ! grep -qE "Usage:|SOT" <<<"$HELP_OUTPUT"; then
  echo "CLI help output did not contain expected usage information" >&2
  echo "$HELP_OUTPUT"
  exit 1
fi

# Check that help shows essential commands
if ! grep -q "setup" <<<"$HELP_OUTPUT"; then
  echo "CLI help output did not list 'setup' command" >&2
  echo "$HELP_OUTPUT"
  exit 1
fi

# Asking for help on a specific command should show command-specific info
SPECIFIC_HELP=$(CONFIG_FILE="$CONFIG_FILE" bash "$CLI_SCRIPT" help setup 2>&1 || true)

# The help should mention the command or provide some output
if [[ -z "$SPECIFIC_HELP" ]]; then
  echo "CLI command specific help returned empty output" >&2
  exit 1
fi

echo "CLI smoke tests completed successfully."
