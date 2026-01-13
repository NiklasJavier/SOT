# Contributing to SOT

Vielen Dank für dein Interesse an SOT! Dieses Dokument beschreibt die Projektstruktur,
Coding-Standards und den Beitragsprozess.

## Projektstruktur

```
SOT/
├── bin/                    # CLI-Einstiegspunkt
│   └── sot                 # Haupt-CLI
├── lib/                    # Gemeinsame Bibliotheken
│   ├── init.sh             # Hauptlader
│   ├── core/               # Kernfunktionen
│   │   ├── colors.sh       # Farbdefinitionen
│   │   ├── yaml_parser.sh  # YAML-Parser
│   │   ├── helpers.sh      # Hilfsfunktionen
│   │   └── setup/          # Setup-spezifische Module
│   ├── cli/                # CLI-System
│   │   ├── registry.sh     # Befehlsregistrierung
│   │   └── integrations.sh # Integrations-Framework
│   └── plugins/            # Plugin-System
│       └── manager.sh      # Plugin-Manager
├── commands/               # CLI-Befehle
│   ├── setup.sh, vault.sh, runner.sh
│   ├── maintenance/        # Wartung (update, delete)
│   └── integrations/       # AAT/TID Sync
├── completions/            # Shell-Completions
├── modules/                # Plugin-Module (ansible, docker, sdkman)
├── setup/                  # Bootstrap-Skripte
├── services/               # Konfigurationsdateien
├── tests/                  # Unit- und Integrations-Tests
├── docs/                   # Dokumentation
└── config/validators/      # Validatoren
```

> Detaillierte Dokumentation: [docs/development.md](docs/development.md)

## Shared Library (`lib/`)

### Verwendung

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/init.sh"

# Jetzt sind alle Funktionen verfügbar
info "Script gestartet"
```

### Verfügbare Funktionen

#### Farben (`lib/core/colors.sh`)

```bash
# Grundfarben
$GREEN, $RED, $YELLOW, $BLUE, $PINK, $CYAN, $GREY, $BOLD, $NC

# Semantische Aliase
$COLOR_SUCCESS, $COLOR_ERROR, $COLOR_WARNING, $COLOR_INFO
```

#### Hilfsfunktionen (`lib/core/helpers.sh`)

```bash
is_true "yes"              # true für: true, TRUE, 1, yes, YES, on, ON
is_false "no"              # true für: false, FALSE, 0, no, NO, off, OFF, ""
info "Nachricht"           # Blaue Info-Ausgabe
success "Erledigt"         # Grüne Erfolgsmeldung
warn "Achtung"             # Gelbe Warnung
err "Fehler"               # Rote Fehlermeldung (nach stderr)
ensure_dir "/path"         # mkdir -p mit Fehlerbehandlung
resolve_path "relative"    # Pfad zu absolutem Pfad auflösen
log_command "cmd"          # Befehl mit Timestamp loggen
```

#### YAML-Parser (`lib/core/yaml_parser.sh`)

```bash
# Flaches YAML (v1)
declare -A config
parse_yaml_to_array "config.yml" config
value=$(get_yaml_value "config.yml" "key")

# Verschachteltes YAML (v2)
declare -A nested
parse_nested_yaml "config.yml" nested
value=$(get_nested_value nested "section.key")

# Smart-Loader (erkennt Format automatisch)
declare -A config
load_config "config.yml" config
# Konvertiert section.key → section_key
```

## Coding-Standards

### Bash-Stil

```bash
#!/usr/bin/env bash
set -euo pipefail

# Konstanten in GROSSBUCHSTABEN
readonly SCRIPT_NAME="example"

# Lokale Variablen in snake_case
local my_variable="value"

# Funktionen in snake_case
my_function() {
    local arg="$1"
    # ...
}

# Fehlerbehandlung mit || true wo nötig
some_command || true

# Arrays korrekt quotieren
for item in "${array[@]}"; do
    echo "$item"
done
```

### Idempotenz-Guards

Alle Library-Dateien verwenden Guards gegen mehrfaches Laden:

```bash
#!/usr/bin/env bash
# Guard against multiple sourcing
[[ -n "${_MY_MODULE_LOADED:-}" ]] && return 0
_MY_MODULE_LOADED=1

# ... Modul-Code ...
```

### Portabilität

- Verwende `#!/usr/bin/env bash` statt `/bin/bash`
- Teste auf macOS und Linux
- Für `tr` mit `/dev/urandom`: Verwende `LC_ALL=C` oder `openssl rand`

```bash
# ✅ Korrekt (portabel)
if command -v openssl &>/dev/null; then
    SECRET=$(openssl rand -base64 64 | tr -dc 'A-Za-z0-9' | head -c 60)
else
    SECRET=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 60)
fi

# ❌ Problematisch auf macOS
SECRET=$(tr -dc '[:upper:]' < /dev/urandom | head -c 11)
```

## Tests

### Tests ausführen

```bash
# Alle Tests
./ci/run-all-tests.sh

# Einzelne Suites
./ci/run-helpers-tests.sh
./ci/run-yaml-tests.sh
./ci/run-setup-tests.sh
./ci/run-integration-tests.sh
```

### Neue Tests hinzufügen

1. Erstelle eine Testdatei unter `ci/run-<name>-tests.sh`
2. Verwende das Standard-Test-Pattern:

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

# Tests
echo "Testing something..."
[[ "expected" == "expected" ]] && \
    run_test "my test" "pass" || \
    run_test "my test" "fail"

# Summary
echo ""
echo "Tests: $TESTS_RUN | Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]] || exit 1
```

3. Füge den Test zu `ci/run-all-tests.sh` hinzu

## Konfigurationsformate

### Format v1 (Flach) — Legacy

```yaml
system_name: "SRV-EXAMPLE"
ssh_port: "282"
aat_enabled: "true"
aat_dir: "/opt/AAT"
```

### Format v2 (Verschachtelt) — Empfohlen

```yaml
system:
  name: "SRV-EXAMPLE"
  username: "__GENERATE_USERNAME__"

ssh:
  port: "282"

aat:
  enabled: "true"
  dir: "/opt/AAT"
```

Der Smart-Loader unterstützt beide Formate und konvertiert automatisch.

## Pull Request Prozess

1. **Fork & Branch**: Erstelle einen Feature-Branch (`feature/my-feature`)
2. **Code**: Implementiere deine Änderungen
3. **Tests**: Stelle sicher, dass alle Tests bestehen: `./ci/run-all-tests.sh`
4. **Syntax-Check**: `bash -n <script.sh>` für alle geänderten Dateien
5. **Dokumentation**: Aktualisiere README.md falls nötig
6. **Commit**: Verwende beschreibende Commit-Messages
7. **Pull Request**: Erstelle einen PR gegen `production`

## Commit-Message Format

```
<type>: <kurze Beschreibung>

<optionaler Body mit Details>

<optionaler Footer>
```

Typen:
- `feat`: Neues Feature
- `fix`: Bugfix
- `refactor`: Code-Refactoring ohne Funktionsänderung
- `docs`: Dokumentationsänderungen
- `test`: Tests hinzufügen/ändern
- `chore`: Build, CI, etc.

Beispiel:
```
feat: Add nested YAML config support

- Implement parse_nested_yaml() function
- Add load_config() smart loader with format auto-detection
- Maintain backwards compatibility with flat config format

Closes #123
```

## Fragen?

Bei Fragen oder Problemen:
- Öffne ein Issue auf GitHub
- Schau in die bestehende Dokumentation unter `README.md`
