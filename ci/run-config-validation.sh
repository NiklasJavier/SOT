#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=./setup-env.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/setup-env.sh"

VALIDATOR="$ROOT_DIR/config/validators/validate_config.sh"
DEFAULT_CONFIG="$ROOT_DIR/services/default_config.yml"

# yamllint is optional - only run if available
if command -v yamllint &>/dev/null; then
  yamllint -d "{extends: relaxed, rules: {line-length: disable}}" "$DEFAULT_CONFIG"
else
  echo "⚠️  yamllint not installed, skipping YAML lint checks"
fi

bash "$VALIDATOR" "$CONFIG_FILE_PATH"

echo "Configuration validation completed successfully."
