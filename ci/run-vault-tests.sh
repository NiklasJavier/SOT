#!/usr/bin/env bash
# =============================================================================
# SOT Vault Tests
# Testet die sichere Vault-Interaktion inkl. Secret-Handling
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

# shellcheck source=./setup-env.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/setup-env.sh"

VAULT_SCRIPT="$ROOT_DIR/scripts/vault.sh"

# =============================================================================
# Test-Hilfsfunktionen
# =============================================================================
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ✅ $1"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ❌ $1"
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "\n🧪 Test $TESTS_RUN: $1"
}

# =============================================================================
# Test 1: Vault-Script Grundfunktionalität
# =============================================================================
run_test "Vault-Script Grundfunktionalität"

# shellcheck disable=SC2154
OUTPUT=$(PATH="$PATH" bash "$VAULT_SCRIPT" placeholder placeholder placeholder "$vault_file" "$vault_secret" 2>&1) || true

if grep -q "Vault-Datei.*existiert" <<<"$OUTPUT" || grep -q "The Vault file" <<<"$OUTPUT"; then
    test_pass "Vault-Script erkennt Vault-Datei"
else
    test_fail "Vault-Script erkennt Vault-Datei nicht"
    echo "$OUTPUT"
fi

if grep -q "Temporäre Zugriffsdatei" <<<"$OUTPUT" || grep -q "Temporary access file" <<<"$OUTPUT"; then
    test_pass "Temporäre Passwortdatei wird erstellt"
else
    test_fail "Temporäre Passwortdatei wird nicht erstellt"
    echo "$OUTPUT"
fi

# =============================================================================
# Test 2: Sichere Löschung der temporären Datei
# =============================================================================
run_test "Sichere Löschung der temporären Datei"

if grep -q "sicher gelöscht" <<<"$OUTPUT" || grep -q "successfully deleted" <<<"$OUTPUT"; then
    test_pass "Temporäre Datei wird sicher gelöscht"
else
    test_fail "Keine Bestätigung der sicheren Löschung"
fi

# Prüfe dass keine vault_* Dateien in /tmp oder /dev/shm zurückbleiben
LEFTOVER_FILES=$(find /tmp /dev/shm 2>/dev/null -name "vault_*" -mmin -1 2>/dev/null || true)
if [[ -z "$LEFTOVER_FILES" ]]; then
    test_pass "Keine temporären Vault-Dateien zurückgeblieben"
else
    test_fail "Temporäre Vault-Dateien gefunden: $LEFTOVER_FILES"
fi

# =============================================================================
# Test 3: Sichere Funktionen im Script
# =============================================================================
run_test "Sichere Funktionen im Script"

# Prüfe ob Script set -euo pipefail verwendet
if grep -q "set -euo pipefail" "$VAULT_SCRIPT"; then
    test_pass "Script verwendet strict mode (set -euo pipefail)"
else
    test_fail "Script verwendet keinen strict mode"
fi

# Prüfe ob shred verwendet wird
if grep -q "shred" "$VAULT_SCRIPT"; then
    test_pass "Script verwendet shred für sichere Löschung"
else
    test_fail "Script verwendet kein shred"
fi

# Prüfe ob trap für Cleanup verwendet wird
if grep -q "trap.*cleanup" "$VAULT_SCRIPT"; then
    test_pass "Script verwendet trap für automatischen Cleanup"
else
    test_fail "Script verwendet keinen trap für Cleanup"
fi

# Prüfe ob chmod vor dem Schreiben kommt
CHMOD_LINE=$(grep -n "chmod 600" "$VAULT_SCRIPT" | head -1 | cut -d: -f1)
PRINTF_LINE=$(grep -n "printf.*vault_secret" "$VAULT_SCRIPT" | head -1 | cut -d: -f1)
if [[ -n "$CHMOD_LINE" && -n "$PRINTF_LINE" && "$CHMOD_LINE" -lt "$PRINTF_LINE" ]]; then
    test_pass "Berechtigungen werden vor dem Schreiben gesetzt"
else
    test_fail "Berechtigungen werden nicht vor dem Schreiben gesetzt"
fi

# =============================================================================
# Test 4: Sichere Verzeichniswahl
# =============================================================================
run_test "Sichere Verzeichniswahl"

if grep -q "dev/shm\|XDG_RUNTIME_DIR\|/run/user" "$VAULT_SCRIPT"; then
    test_pass "Script bevorzugt RAM-basierte Verzeichnisse"
else
    test_fail "Script verwendet unsichere Verzeichnisse"
fi

# =============================================================================
# Test 5: Ansible Vault Role Sicherheit
# =============================================================================
run_test "Ansible Vault Role Sicherheit"

VAULT_TASKS="$ROOT_DIR/modules/ansible/roles/vault/tasks/main.yml"

if grep -q "no_log: true" "$VAULT_TASKS"; then
    test_pass "Ansible Role verhindert Secret-Logging"
else
    test_fail "Ansible Role loggt möglicherweise Secrets"
fi

if grep -q "shred" "$VAULT_TASKS"; then
    test_pass "Ansible Role verwendet shred für Cleanup"
else
    test_fail "Ansible Role verwendet kein shred"
fi

if grep -q "/dev/shm\|secure_tmp_dir" "$VAULT_TASKS"; then
    test_pass "Ansible Role verwendet sichere temporäre Verzeichnisse"
else
    test_fail "Ansible Role verwendet /tmp direkt"
fi

if grep -q "always:" "$VAULT_TASKS"; then
    test_pass "Ansible Role hat always-Block für Cleanup"
else
    test_fail "Ansible Role hat keinen garantierten Cleanup"
fi

# =============================================================================
# Zusammenfassung
# =============================================================================
echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "📊 Vault Security Tests: $TESTS_PASSED/$TESTS_RUN passed"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "❌ $TESTS_FAILED Tests fehlgeschlagen"
    exit 1
else
    echo -e "✅ Alle Vault Security Tests bestanden!"
fi
