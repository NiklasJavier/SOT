#!/usr/bin/env bash
# =============================================================================
# SOT Configuration Validation Tests
# =============================================================================
# Validiert die Konfigurationsdateien auf Syntax und erforderliche Felder
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

# shellcheck source=../setup-env.sh
# shellcheck disable=SC1091
[[ -f "$SCRIPT_DIR/../setup-env.sh" ]] && source "$SCRIPT_DIR/../setup-env.sh"

# Library laden für YAML-Parser
source "$ROOT_DIR/lib/init.sh"

DEFAULT_CONFIG="$ROOT_DIR/services/default_config.yml"
TEST_PASSED=0
TEST_FAILED=0

pass() { echo "  ✓ $1"; ((++TEST_PASSED)) || true; }
fail() { echo "  ✗ $1"; ((++TEST_FAILED)) || true; }

echo "Testing configuration validation..."

# =============================================================================
# Test 1: YAML Syntax Validation
# =============================================================================
echo ""
echo "Testing YAML syntax..."

if command -v yamllint &>/dev/null; then
    if yamllint -d "{extends: relaxed, rules: {line-length: disable}}" "$DEFAULT_CONFIG" >/dev/null 2>&1; then
        pass "default_config.yml has valid YAML syntax (yamllint)"
    else
        fail "default_config.yml has YAML syntax errors"
    fi
else
    # Fallback: Verwende den integrierten YAML-Parser
    if parse_yaml_to_vars "$DEFAULT_CONFIG" 2>/dev/null; then
        pass "default_config.yml is parseable (builtin parser)"
    else
        fail "default_config.yml cannot be parsed"
    fi
fi

# =============================================================================
# Test 2: Required Fields Check
# =============================================================================
echo ""
echo "Testing required configuration fields..."

# Parse config
declare -A config=()
if [[ -f "$DEFAULT_CONFIG" ]]; then
    parse_yaml_to_vars "$DEFAULT_CONFIG"
fi

# Check required fields
required_fields=(
    "system_name"
    "ssh_port"
)

for field in "${required_fields[@]}"; do
    if [[ -n "${!field:-}" ]]; then
        pass "Required field '$field' is set"
    else
        fail "Required field '$field' is missing"
    fi
done

# =============================================================================
# Test 3: Value Validation
# =============================================================================
echo ""
echo "Testing configuration values..."

# SSH Port should be numeric
if [[ "${ssh_port:-22}" =~ ^[0-9]+$ ]]; then
    pass "ssh_port is numeric"
else
    fail "ssh_port is not numeric"
fi

# SSH Port should be in valid range
if [[ "${ssh_port:-22}" -ge 1 && "${ssh_port:-22}" -le 65535 ]]; then
    pass "ssh_port is in valid range (1-65535)"
else
    fail "ssh_port is out of range"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=============================================="
echo "Config Validation Test Summary"
echo "=============================================="
echo "Tests passed: $TEST_PASSED"
echo "Tests failed: $TEST_FAILED"
echo "=============================================="

if [[ $TEST_FAILED -gt 0 ]]; then
    echo "❌ Some configuration tests failed!"
    exit 1
fi

echo "✅ Configuration validation completed successfully."
