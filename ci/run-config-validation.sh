#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=./setup-env.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/setup-env.sh"

VALIDATOR="$ROOT_DIR/config/validators/validate_config.sh"
DEFAULT_CONFIG="$ROOT_DIR/services/default_config.yml"

yamllint -d "{extends: relaxed, rules: {line-length: disable}}" "$DEFAULT_CONFIG"

bash "$VALIDATOR" "$CONFIG_FILE"

echo "Configuration validation completed successfully."
