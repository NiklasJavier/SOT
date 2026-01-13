#!/usr/bin/env bash
# =============================================================================
# SOT Test Suite: Bootstrap Library Functions
# =============================================================================
# Tests for lib/core/bootstrap/*.sh modules
# shellcheck disable=SC2015  # Using && || pattern intentionally for test assertions
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

# shellcheck source=./setup-env.sh
[[ -f "$SCRIPT_DIR/../setup-env.sh" ]] && source "$SCRIPT_DIR/../setup-env.sh"

# Load the bootstrap library
source "$ROOT_DIR/lib/core/bootstrap/init.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
  ((TESTS_PASSED++))
  echo "  ✓ $1"
}

test_fail() {
  ((TESTS_FAILED++))
  echo "  ✗ $1" >&2
}

run_test() {
  local name="$1"
  local result="$2"
  ((TESTS_RUN++))
  
  if [[ "$result" == "pass" ]]; then
    test_pass "$name"
  else
    test_fail "$name"
  fi
}

# =============================================================================
# Test: Config Defaults Loading
# =============================================================================
echo "Testing config defaults loading..."

# Reset CONFIG_DEFAULTS
declare -A CONFIG_DEFAULTS=()

load_default_config "$ROOT_DIR/config/default_config.yml"

[[ -n "${CONFIG_DEFAULTS[ssh_port]:-}" ]] && \
  run_test "load_default_config loads ssh_port" "pass" || \
  run_test "load_default_config loads ssh_port" "fail"

[[ "${CONFIG_DEFAULTS[ssh_port]}" == "282" ]] && \
  run_test "ssh_port value is correct" "pass" || \
  run_test "ssh_port value is correct" "fail"

[[ -n "${CONFIG_DEFAULTS[aat_enabled]:-}" ]] && \
  run_test "load_default_config loads aat_enabled" "pass" || \
  run_test "load_default_config loads aat_enabled" "fail"

# =============================================================================
# Test: Apply Config Defaults
# =============================================================================
echo "Testing apply_config_defaults..."

# Clear variables first
unset SSH_PORT AAT_ENABLED 2>/dev/null || true

apply_config_defaults

[[ -n "${SSH_PORT:-}" ]] && \
  run_test "apply_config_defaults sets SSH_PORT" "pass" || \
  run_test "apply_config_defaults sets SSH_PORT" "fail"

[[ "${SSH_PORT:-}" == "282" ]] && \
  run_test "SSH_PORT value is correct" "pass" || \
  run_test "SSH_PORT value is correct" "fail"

# =============================================================================
# Test: ensure_sdkman_default
# =============================================================================
echo "Testing ensure_sdkman_default..."

TOOLS="ansible docker"
ensure_sdkman_default

[[ "$TOOLS" == *"sdkman"* ]] && \
  run_test "ensure_sdkman_default adds sdkman" "pass" || \
  run_test "ensure_sdkman_default adds sdkman" "fail"

# Test deduplication
TOOLS="ansible ansible docker docker sdkman"
ensure_sdkman_default

# Count occurrences
ANSIBLE_COUNT=$(echo "$TOOLS" | tr ' ' '\n' | grep -c "^ansible$" || true)
[[ "$ANSIBLE_COUNT" -eq 1 ]] && \
  run_test "ensure_sdkman_default deduplicates" "pass" || \
  run_test "ensure_sdkman_default deduplicates" "fail"

# =============================================================================
# Test: generate_dynamic_defaults
# =============================================================================
echo "Testing generate_dynamic_defaults..."

# Reset variables
USERNAME=""
SYSTEM_NAME=""
CLONE_DIR=""

# Set LC_ALL for macOS tr compatibility
export LC_ALL=C

generate_dynamic_defaults

[[ -n "$USERNAME" ]] && \
  run_test "generate_dynamic_defaults sets USERNAME" "pass" || \
  run_test "generate_dynamic_defaults sets USERNAME" "fail"

[[ -n "$SYSTEM_NAME" ]] && \
  run_test "generate_dynamic_defaults sets SYSTEM_NAME" "pass" || \
  run_test "generate_dynamic_defaults sets SYSTEM_NAME" "fail"

[[ "$SYSTEM_NAME" == "SRV-$USERNAME" ]] && \
  run_test "SYSTEM_NAME format is correct" "pass" || \
  run_test "SYSTEM_NAME format is correct" "fail"

[[ -n "$CLONE_DIR" ]] && \
  run_test "generate_dynamic_defaults sets CLONE_DIR" "pass" || \
  run_test "generate_dynamic_defaults sets CLONE_DIR" "fail"

[[ -n "$VAULT_FILE" ]] && \
  run_test "generate_dynamic_defaults sets VAULT_FILE" "pass" || \
  run_test "generate_dynamic_defaults sets VAULT_FILE" "fail"

[[ -n "$VAULT_SECRET" && ${#VAULT_SECRET} -ge 20 ]] && \
  run_test "VAULT_SECRET is generated (min 20 chars)" "pass" || \
  run_test "VAULT_SECRET is generated (min 20 chars)" "fail"

# =============================================================================
# Test: Argument Parser (parse_early_args simulation)
# =============================================================================
echo "Testing argument parser..."

# Test that variables can be set
DEFAULT_CONFIG_FILE="/some/path"
DEFAULT_BRANCH_HINT="test-branch"

parse_early_args -branch main -config /custom/config.yml

[[ "$DEFAULT_BRANCH_HINT" == "main" ]] && \
  run_test "parse_early_args sets branch" "pass" || \
  run_test "parse_early_args sets branch" "fail"

[[ "$DEFAULT_CONFIG_FILE" == "/custom/config.yml" ]] && \
  run_test "parse_early_args sets config" "pass" || \
  run_test "parse_early_args sets config" "fail"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=============================================="
echo "Bootstrap Library Test Summary"
echo "=============================================="
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "=============================================="

if [[ $TESTS_FAILED -gt 0 ]]; then
  exit 1
fi

echo "All bootstrap library tests passed!"
