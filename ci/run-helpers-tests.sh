#!/usr/bin/env bash
# =============================================================================
# SOT Test Suite: Shared Library Functions
# =============================================================================
# Tests for lib/helpers.sh functions
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

# Load the library
source "$ROOT_DIR/lib/init.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
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
# Test: is_true function
# =============================================================================
echo "Testing is_true()..."

is_true "true" && run_test "is_true 'true'" "pass" || run_test "is_true 'true'" "fail"
is_true "TRUE" && run_test "is_true 'TRUE'" "pass" || run_test "is_true 'TRUE'" "fail"
is_true "True" && run_test "is_true 'True'" "pass" || run_test "is_true 'True'" "fail"
is_true "1" && run_test "is_true '1'" "pass" || run_test "is_true '1'" "fail"
is_true "yes" && run_test "is_true 'yes'" "pass" || run_test "is_true 'yes'" "fail"
is_true "YES" && run_test "is_true 'YES'" "pass" || run_test "is_true 'YES'" "fail"
is_true "on" && run_test "is_true 'on'" "pass" || run_test "is_true 'on'" "fail"
is_true "ON" && run_test "is_true 'ON'" "pass" || run_test "is_true 'ON'" "fail"

! is_true "false" && run_test "!is_true 'false'" "pass" || run_test "!is_true 'false'" "fail"
! is_true "0" && run_test "!is_true '0'" "pass" || run_test "!is_true '0'" "fail"
! is_true "no" && run_test "!is_true 'no'" "pass" || run_test "!is_true 'no'" "fail"
! is_true "" && run_test "!is_true ''" "pass" || run_test "!is_true ''" "fail"
! is_true "random" && run_test "!is_true 'random'" "pass" || run_test "!is_true 'random'" "fail"

# =============================================================================
# Test: is_false function
# =============================================================================
echo "Testing is_false()..."

is_false "false" && run_test "is_false 'false'" "pass" || run_test "is_false 'false'" "fail"
is_false "FALSE" && run_test "is_false 'FALSE'" "pass" || run_test "is_false 'FALSE'" "fail"
is_false "0" && run_test "is_false '0'" "pass" || run_test "is_false '0'" "fail"
is_false "no" && run_test "is_false 'no'" "pass" || run_test "is_false 'no'" "fail"
is_false "off" && run_test "is_false 'off'" "pass" || run_test "is_false 'off'" "fail"
is_false "" && run_test "is_false ''" "pass" || run_test "is_false ''" "fail"

! is_false "true" && run_test "!is_false 'true'" "pass" || run_test "!is_false 'true'" "fail"
! is_false "1" && run_test "!is_false '1'" "pass" || run_test "!is_false '1'" "fail"
! is_false "yes" && run_test "!is_false 'yes'" "pass" || run_test "!is_false 'yes'" "fail"

# =============================================================================
# Test: ensure_dir function
# =============================================================================
echo "Testing ensure_dir()..."

TEST_DIR="$SCRIPT_DIR/tmp/test_ensure_dir_$$"
rm -rf "$TEST_DIR" 2>/dev/null || true

ensure_dir "$TEST_DIR" && [[ -d "$TEST_DIR" ]] && \
  run_test "ensure_dir creates directory" "pass" || \
  run_test "ensure_dir creates directory" "fail"

ensure_dir "$TEST_DIR" && \
  run_test "ensure_dir on existing directory" "pass" || \
  run_test "ensure_dir on existing directory" "fail"

rm -rf "$TEST_DIR" 2>/dev/null || true

# =============================================================================
# Test: resolve_path function
# =============================================================================
echo "Testing resolve_path()..."

RESOLVED=$(resolve_path "/absolute/path")
[[ "$RESOLVED" == "/absolute/path" ]] && \
  run_test "resolve_path absolute" "pass" || \
  run_test "resolve_path absolute" "fail"

# =============================================================================
# Test: Color variables are set
# =============================================================================
echo "Testing color variables..."

[[ -n "$GREEN" ]] && run_test "GREEN is set" "pass" || run_test "GREEN is set" "fail"
[[ -n "$RED" ]] && run_test "RED is set" "pass" || run_test "RED is set" "fail"
[[ -n "$YELLOW" ]] && run_test "YELLOW is set" "pass" || run_test "YELLOW is set" "fail"
[[ -n "$NC" ]] && run_test "NC is set" "pass" || run_test "NC is set" "fail"
[[ -n "$GREY" ]] && run_test "GREY is set" "pass" || run_test "GREY is set" "fail"
[[ -n "$PINK" ]] && run_test "PINK is set" "pass" || run_test "PINK is set" "fail"

# =============================================================================
# Test: Semantic color aliases
# =============================================================================
echo "Testing semantic color aliases..."

[[ "$COLOR_SUCCESS" == "$GREEN" ]] && \
  run_test "COLOR_SUCCESS = GREEN" "pass" || \
  run_test "COLOR_SUCCESS = GREEN" "fail"

[[ "$COLOR_ERROR" == "$RED" ]] && \
  run_test "COLOR_ERROR = RED" "pass" || \
  run_test "COLOR_ERROR = RED" "fail"

[[ "$COLOR_WARNING" == "$YELLOW" ]] && \
  run_test "COLOR_WARNING = YELLOW" "pass" || \
  run_test "COLOR_WARNING = YELLOW" "fail"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=============================================="
echo "Helpers Test Summary"
echo "=============================================="
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "=============================================="

if [[ $TESTS_FAILED -gt 0 ]]; then
  exit 1
fi

echo "All helper tests passed!"
