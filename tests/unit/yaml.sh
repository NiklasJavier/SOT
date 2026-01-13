#!/usr/bin/env bash
# Test script for the nested YAML parser
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

# shellcheck source=./setup-env.sh
[[ -f "$SCRIPT_DIR/../setup-env.sh" ]] && source "$SCRIPT_DIR/../setup-env.sh"

# Load the YAML parser library
source "$ROOT_DIR/lib/core/yaml_parser.sh"

echo "Testing YAML parser with flat config (v1)..."

# Test flat config parsing
declare -A FLAT_CFG
parse_yaml_to_array "$ROOT_DIR/config/default_config.yml" FLAT_CFG

if [[ "${FLAT_CFG[ssh_port]}" != "282" ]]; then
  echo "FAIL: Expected ssh_port=282, got ${FLAT_CFG[ssh_port]:-<empty>}" >&2
  exit 1
fi

if [[ "${FLAT_CFG[aat_enabled]}" != "true" ]]; then
  echo "FAIL: Expected aat_enabled=true, got ${FLAT_CFG[aat_enabled]:-<empty>}" >&2
  exit 1
fi

echo "✓ Flat config parsing works"

echo "Testing YAML parser with nested config (v2)..."

# Test nested config parsing
declare -A NESTED_CFG
parse_nested_yaml "$ROOT_DIR/config/default_config_v2.yml" NESTED_CFG

if [[ "${NESTED_CFG[ssh.port]}" != "282" ]]; then
  echo "FAIL: Expected ssh.port=282, got ${NESTED_CFG[ssh.port]:-<empty>}" >&2
  exit 1
fi

if [[ "${NESTED_CFG[aat.enabled]}" != "true" ]]; then
  echo "FAIL: Expected aat.enabled=true, got ${NESTED_CFG[aat.enabled]:-<empty>}" >&2
  exit 1
fi

echo "✓ Nested config parsing works"

echo "Testing get_nested_value function..."

SSH_PORT=$(get_nested_value "$ROOT_DIR/config/default_config_v2.yml" "ssh.port" "22")
if [[ "$SSH_PORT" != "282" ]]; then
  echo "FAIL: get_nested_value returned $SSH_PORT instead of 282" >&2
  exit 1
fi

AAT_ENABLED=$(get_nested_value "$ROOT_DIR/config/default_config_v2.yml" "aat.enabled" "false")
if [[ "$AAT_ENABLED" != "true" ]]; then
  echo "FAIL: get_nested_value returned $AAT_ENABLED instead of true" >&2
  exit 1
fi

echo "✓ get_nested_value works"

echo "Testing smart config loader (load_config)..."

# Test smart loader with flat config
declare -A SMART_FLAT
load_config "$ROOT_DIR/config/default_config.yml" SMART_FLAT

if [[ "${SMART_FLAT[ssh_port]}" != "282" ]]; then
  echo "FAIL: load_config (flat) returned wrong ssh_port" >&2
  exit 1
fi

echo "✓ Smart loader works with flat config"

# Test smart loader with nested config
declare -A SMART_NESTED
load_config "$ROOT_DIR/config/default_config_v2.yml" SMART_NESTED

if [[ "${SMART_NESTED[ssh_port]}" != "282" ]]; then
  echo "FAIL: load_config (nested) returned wrong ssh_port: ${SMART_NESTED[ssh_port]:-<empty>}" >&2
  exit 1
fi

if [[ "${SMART_NESTED[aat_enabled]}" != "true" ]]; then
  echo "FAIL: load_config (nested) returned wrong aat_enabled: ${SMART_NESTED[aat_enabled]:-<empty>}" >&2
  exit 1
fi

echo "✓ Smart loader works with nested config (converts to flat keys)"

echo ""
echo "All YAML parser tests passed successfully!"
