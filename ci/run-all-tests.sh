#!/usr/bin/env bash
# =============================================================================
# SOT Test Suite: Run All Tests
# =============================================================================
# Master test runner that executes all test suites
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo "=============================================="
echo "  SOT Test Suite"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================="
echo ""

TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

run_suite() {
  local name="$1"
  local script="$2"
  
  TOTAL_SUITES=$((TOTAL_SUITES + 1))
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Running: $name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  if "$script"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
    echo ""
  else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    echo ""
    echo "⚠️  Suite failed: $name"
    echo ""
  fi
}

# Run all test suites
run_suite "Helper Functions" "$SCRIPT_DIR/run-helpers-tests.sh"
run_suite "YAML Parser" "$SCRIPT_DIR/run-yaml-tests.sh"
run_suite "Setup Library" "$SCRIPT_DIR/run-setup-tests.sh"
run_suite "CLI Tests" "$SCRIPT_DIR/run-cli-tests.sh"
run_suite "Integration Tests" "$SCRIPT_DIR/run-integration-tests.sh"
run_suite "Config Validation" "$SCRIPT_DIR/run-config-validation.sh"
run_suite "Vault Tests" "$SCRIPT_DIR/run-vault-tests.sh"

# Summary
echo ""
echo "=============================================="
echo "  FINAL SUMMARY"
echo "=============================================="
echo "Total suites:  $TOTAL_SUITES"
echo "Passed:        $PASSED_SUITES"
echo "Failed:        $FAILED_SUITES"
echo "=============================================="

if [[ $FAILED_SUITES -gt 0 ]]; then
  echo ""
  echo "❌ Some test suites failed!"
  exit 1
fi

echo ""
echo "✅ All test suites passed!"
exit 0
