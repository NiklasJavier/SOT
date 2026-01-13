# SOT CI Test Suite

Dieses Verzeichnis enthält die automatisierten Tests für SOT.

## Tests ausführen

```bash
# Alle Tests
./ci/run-all-tests.sh

# Einzelne Test-Suites
./ci/run-helpers-tests.sh      # Hilfsfunktionen (34 Tests)
./ci/run-yaml-tests.sh         # YAML-Parser (5 Tests)
./ci/run-setup-tests.sh        # Setup-Library (15 Tests)
./ci/run-integration-tests.sh  # Integrationstests (15 Tests)
./ci/run-cli-tests.sh          # CLI Smoke-Tests
./ci/run-config-validation.sh  # Config-Validierung
./ci/run-vault-tests.sh        # Vault-Workflow
```

## Test-Suites

| Suite | Beschreibung | Tests |
|-------|--------------|-------|
| `run-helpers-tests.sh` | `is_true()`, `is_false()`, Farben, `ensure_dir()` | 34 |
| `run-yaml-tests.sh` | YAML-Parser (flach, verschachtelt, Smart-Loader) | 5 |
| `run-setup-tests.sh` | Config-Defaults, Argument-Parser, dynamische Werte | 15 |
| `run-integration-tests.sh` | CLI, Library-Loading, Config-Parsing | 15 |
| `run-cli-tests.sh` | CLI Smoke-Tests | - |
| `run-config-validation.sh` | YAML-Validierung (optional: yamllint) | - |
| `run-vault-tests.sh` | Vault-Workflow Tests | - |

## Verzeichnisstruktur

```
ci/
├── run-all-tests.sh         # Master Test-Runner
├── run-helpers-tests.sh     # Unit-Tests lib/helpers.sh
├── run-yaml-tests.sh        # Unit-Tests lib/yaml_parser.sh
├── run-setup-tests.sh       # Unit-Tests lib/setup/*
├── run-integration-tests.sh # End-to-End Tests
├── run-cli-tests.sh         # CLI Smoke-Tests
├── run-config-validation.sh # Config-Validierung
├── run-vault-tests.sh       # Vault-Workflow
├── setup-env.sh             # CI-Umgebung Setup
├── bin/                     # Mock-Binaries (ansible-vault)
├── tmp/                     # Temporäre Testdateien
└── pipelines/               # CI/CD Pipeline-Definitionen
```

## CI-Umgebung

`setup-env.sh` richtet die Testumgebung ein:

- Erstellt temporäre Verzeichnisse (`$CI_TMP_DIR`)
- Stellt Mock-`ansible-vault` bereit
- Generiert Test-Konfigurationsdateien
- Setzt Umgebungsvariablen:
  - `$CONFIG_FILE_PATH` — Pfad zur Test-Config
  - `$VAULT_FILE_PATH` — Pfad zur Test-Vault
  - `$ROOT_DIR` — Projekt-Root

## Neue Tests hinzufügen

1. Erstelle `ci/run-<name>-tests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$ROOT_DIR/lib/init.sh"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local name="$1"
    local result="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$result" == "pass" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "  ✓ $name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "  ✗ $name" >&2
    fi
}

echo "Testing my feature..."
[[ "expected" == "expected" ]] && \
    run_test "my test" "pass" || \
    run_test "my test" "fail"

echo ""
echo "Tests: $TESTS_RUN | Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]] || exit 1
```

2. Mache ausführbar: `chmod +x ci/run-<name>-tests.sh`

3. Füge zu `run-all-tests.sh` hinzu:
```bash
run_suite "My Feature" "$SCRIPT_DIR/run-<name>-tests.sh"
```

## Optionale Abhängigkeiten

- `yamllint` — Für erweiterte YAML-Validierung (optional)

Ohne yamllint werden die entsprechenden Tests übersprungen.
