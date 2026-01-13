#!/usr/bin/env bash
# =============================================================================
# SOT Test Suite: Integration Tests
# =============================================================================
# End-to-end tests for CLI and script interactions
# shellcheck disable=SC2015  # Using && || pattern intentionally for test assertions
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

# shellcheck source=./setup-env.sh
source "$SCRIPT_DIR/setup-env.sh"

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

CLI_SCRIPT="$ROOT_DIR/setup/cli_wrapper.sh"

# =============================================================================
# Test: CLI Help Output
# =============================================================================
echo "Testing CLI help output..."

HELP_OUTPUT=$(CONFIG_FILE="$CONFIG_FILE_PATH" "$CLI_SCRIPT" help 2>&1 || true)

[[ "$HELP_OUTPUT" == *"Usage:"* || "$HELP_OUTPUT" == *"SOT"* ]] && \
  run_test "CLI help shows usage information" "pass" || \
  run_test "CLI help shows usage information" "fail"

[[ "$HELP_OUTPUT" == *"setup"* ]] && \
  run_test "CLI help mentions 'setup' command" "pass" || \
  run_test "CLI help mentions 'setup' command" "fail"

# =============================================================================
# Test: Script Discovery
# =============================================================================
echo "Testing script discovery..."

# Check that expected scripts exist
[[ -f "$ROOT_DIR/scripts/setup.sh" ]] && \
  run_test "scripts/setup.sh exists" "pass" || \
  run_test "scripts/setup.sh exists" "fail"

[[ -f "$ROOT_DIR/scripts/runner.sh" ]] && \
  run_test "scripts/runner.sh exists" "pass" || \
  run_test "scripts/runner.sh exists" "fail"

[[ -f "$ROOT_DIR/scripts/vault.sh" ]] && \
  run_test "scripts/vault.sh exists" "pass" || \
  run_test "scripts/vault.sh exists" "fail"

[[ -d "$ROOT_DIR/scripts/integrations" ]] && \
  run_test "scripts/integrations/ directory exists" "pass" || \
  run_test "scripts/integrations/ directory exists" "fail"

# =============================================================================
# Test: Library Loading
# =============================================================================
echo "Testing library loading..."

# Test that all library files can be sourced without error
(
  source "$ROOT_DIR/lib/init.sh"
  [[ -n "${_SOT_LIB_INIT_LOADED:-}" ]]
) && run_test "lib/init.sh loads successfully" "pass" || \
     run_test "lib/init.sh loads successfully" "fail"

(
  source "$ROOT_DIR/lib/setup/init.sh"
  [[ -n "${_SOT_SETUP_LIB_INIT_LOADED:-}" ]]
) && run_test "lib/setup/init.sh loads successfully" "pass" || \
     run_test "lib/setup/init.sh loads successfully" "fail"

# =============================================================================
# Test: Multiple Library Sourcing (idempotency)
# =============================================================================
echo "Testing library idempotency..."

(
  source "$ROOT_DIR/lib/init.sh"
  source "$ROOT_DIR/lib/init.sh"
  source "$ROOT_DIR/lib/init.sh"
  echo "OK"
) | grep -q "OK" && \
  run_test "lib/init.sh can be sourced multiple times" "pass" || \
  run_test "lib/init.sh can be sourced multiple times" "fail"

# =============================================================================
# Test: Config File Loading
# =============================================================================
echo "Testing config file loading..."

# Create a test config
TEST_CONFIG="$CI_TMP_DIR/test_config_$$.yml"
cat > "$TEST_CONFIG" <<EOF
system_name: "test-system"
username: "test-user"
ssh_port: "2222"
log_level: "debug"
aat_enabled: "false"
EOF

# Load the library and parse using simple method
source "$ROOT_DIR/lib/yaml_parser.sh"
declare -A TEST_CFG
parse_yaml_to_array "$TEST_CONFIG" TEST_CFG

[[ "${TEST_CFG[system_name]:-}" == "test-system" ]] && \
  run_test "Config loads system_name" "pass" || \
  run_test "Config loads system_name" "fail"

[[ "${TEST_CFG[ssh_port]:-}" == "2222" ]] && \
  run_test "Config loads custom ssh_port" "pass" || \
  run_test "Config loads custom ssh_port" "fail"

[[ "${TEST_CFG[aat_enabled]:-}" == "false" ]] && \
  run_test "Config loads aat_enabled=false" "pass" || \
  run_test "Config loads aat_enabled=false" "fail"

rm -f "$TEST_CONFIG"

# =============================================================================
# Test: Nested Config Loading
# =============================================================================
echo "Testing nested config loading..."

TEST_NESTED_CONFIG="$CI_TMP_DIR/test_nested_$$.yml"
cat > "$TEST_NESTED_CONFIG" <<EOF
system:
  name: "nested-test"
  username: "nested-user"

ssh:
  port: "3333"

aat:
  enabled: "true"
  dir: "/custom/aat"
EOF

declare -A NESTED_CFG
load_config "$TEST_NESTED_CONFIG" NESTED_CFG

[[ "${NESTED_CFG[system_name]:-}" == "nested-test" ]] && \
  run_test "Nested config converts system.name -> system_name" "pass" || \
  run_test "Nested config converts system.name -> system_name" "fail"

[[ "${NESTED_CFG[ssh_port]:-}" == "3333" ]] && \
  run_test "Nested config converts ssh.port -> ssh_port" "pass" || \
  run_test "Nested config converts ssh.port -> ssh_port" "fail"

[[ "${NESTED_CFG[aat_enabled]:-}" == "true" ]] && \
  run_test "Nested config converts aat.enabled -> aat_enabled" "pass" || \
  run_test "Nested config converts aat.enabled -> aat_enabled" "fail"

rm -f "$TEST_NESTED_CONFIG"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=============================================="
echo "Integration Test Summary"
echo "=============================================="
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "=============================================="

if [[ $TESTS_FAILED -gt 0 ]]; then
  exit 1
fi

echo "All integration tests passed!"
