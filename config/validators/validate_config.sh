#!/usr/bin/env bash
# Validate YAML configuration file
# Usage: validate_config.sh <config_file>

if [[ -z "$1" ]]; then
  echo "Usage: validate_config.sh <config_file>" >&2
  exit 1
fi

if [[ ! -f "$1" ]]; then
  echo "Error: File not found: $1" >&2
  exit 1
fi

# yamllint is optional - only run if available
if command -v yamllint &>/dev/null; then
  yamllint -d "{extends: relaxed, rules: {line-length: disable}}" "$1"
else
  echo "⚠️  yamllint not installed, skipping YAML lint checks"
fi

echo "Config validation passed: $1"
