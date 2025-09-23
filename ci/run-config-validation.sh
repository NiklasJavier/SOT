#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=./setup-env.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/setup-env.sh"

VALIDATOR="$ROOT_DIR/config/validators/validate_config.sh"

yamllint -d "{extends: relaxed, rules: {line-length: disable}}" "$ROOT_DIR/config/defaults/default_config.yml"

bash "$VALIDATOR" "$CONFIG_FILE"

echo "Configuration validation completed successfully."
