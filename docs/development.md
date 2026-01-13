# SOT Entwicklung

Leitfaden für Entwickler, die zum SOT-Projekt beitragen möchten.

## Voraussetzungen

- **Bash 5.0+**
- **Git**
- **ShellCheck** (für Linting)
- **yamllint** (für YAML-Validierung)

```bash
# macOS
brew install bash shellcheck yamllint

# Ubuntu/Debian
sudo apt-get install bash shellcheck yamllint
```

## Entwicklungsumgebung

### Repository klonen

```bash
git clone https://github.com/NiklasJavier/SOT.git
cd SOT
```

### Pre-Commit Hooks installieren

```bash
pip install pre-commit
pre-commit install
```

### VS Code Extensions

Empfohlene Extensions (`.vscode/extensions.json`):
- ShellCheck
- YAML
- EditorConfig

---

## Projektstruktur

```
SOT/
├── lib/                    # Shared Library (Basis)
│   ├── init.sh             # Hauptlader
│   ├── colors.sh           # Farben
│   ├── yaml_parser.sh      # YAML-Parser
│   ├── helpers.sh          # Hilfsfunktionen
│   └── setup/              # Setup-Module
│
├── scripts/                # CLI-Befehle
│   ├── setup.sh
│   ├── vault.sh
│   ├── runner.sh
│   ├── integrations/       # AAT/TID Sync
│   └── maintenance/        # Update/Delete
│
├── modules/                # Installierbare Module
├── services/               # Konfiguration
├── setup/                  # Bootstrap
├── ci/                     # Tests
├── docs/                   # Dokumentation
└── templates/              # Wiederverwendbare Templates
```

---

## Code-Standards

### Bash-Style

```bash
#!/usr/bin/env bash
#
# Beschreibung des Skripts
#
set -euo pipefail

# Bibliothek laden
SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_ROOT/../lib/init.sh"

# Funktionen mit Dokumentation
# Arguments:
#   $1 - Beschreibung
# Returns:
#   0 on success
my_function() {
    local arg="$1"
    # ...
}

# Hauptprogramm
main() {
    # ...
}

main "$@"
```

### Regeln

| Regel | Beschreibung |
|-------|--------------|
| `set -euo pipefail` | Immer am Anfang |
| `#!/usr/bin/env bash` | Portabler Shebang |
| `local` | Für Funktionsvariablen |
| `"$var"` | Variablen immer quoten |
| `[[ ]]` | Statt `[ ]` für Tests |

### Logging

```bash
# Verwende lib/helpers.sh Funktionen
info "Informative Nachricht"
success "Erfolgsmeldung"
warn "Warnung"
err "Fehler"
```

---

## Tests

### Tests ausführen

```bash
# Alle Tests
./ci/run-all-tests.sh

# Einzelne Suites
./ci/run-helpers-tests.sh   # Hilfsfunktionen
./ci/run-yaml-tests.sh      # YAML-Parser
./ci/run-setup-tests.sh     # Setup-Library
./ci/run-integration-tests.sh # Integration
```

### Test schreiben

```bash
# In ci/run-*-tests.sh

test_my_feature() {
    local result
    result=$(my_function "input")
    
    if [[ "$result" == "expected" ]]; then
        pass "my_feature works"
    else
        fail "my_feature failed: got '$result'"
    fi
}

# Test registrieren
TESTS+=(test_my_feature)
```

### Test-Hilfsfunktionen

```bash
pass "message"              # Test bestanden
fail "message"              # Test fehlgeschlagen
skip "message"              # Test übersprungen
assert_equals "$a" "$b"     # Gleichheit prüfen
assert_true "$condition"    # Boolean prüfen
```

---

## Neues Feature entwickeln

### 1. Branch erstellen

```bash
git checkout -b feature/my-feature
```

### 2. Code schreiben

- Folge den Code-Standards
- Füge Tests hinzu
- Aktualisiere Dokumentation

### 3. Tests lokal ausführen

```bash
./ci/run-all-tests.sh
```

### 4. Linting prüfen

```bash
shellcheck lib/*.sh scripts/*.sh
yamllint .
```

### 5. Commit erstellen

```bash
git add .
git commit -m "feat(scope): Beschreibung

- Detail 1
- Detail 2"
```

### 6. Pull Request

```bash
git push origin feature/my-feature
# PR auf GitHub erstellen
```

---

## Commit-Konventionen

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

| Type | Beschreibung |
|------|--------------|
| `feat` | Neues Feature |
| `fix` | Bugfix |
| `docs` | Dokumentation |
| `style` | Formatierung |
| `refactor` | Refactoring |
| `test` | Tests |
| `chore` | Wartung |

### Beispiele

```
feat(vault): Sichere Löschung mit shred implementiert
fix(sync): Timeout für Git-Operationen hinzugefügt
docs(readme): Badges auf dynamische CI-Status aktualisiert
refactor(lib): find_config_file_arg in helpers.sh extrahiert
```

---

## Debugging

### Verbose-Modus

```bash
DEBUG=1 SOT setup
```

### Bash-Tracing

```bash
bash -x scripts/setup.sh
```

### ShellCheck lokal

```bash
shellcheck -S warning scripts/myfile.sh
```

---

## Release-Prozess

1. **Version bump** in relevanten Dateien
2. **CHANGELOG.md** aktualisieren
3. **Tag erstellen**:
   ```bash
   git tag -a v1.2.3 -m "Release v1.2.3"
   git push origin v1.2.3
   ```
4. **GitHub Release** wird automatisch erstellt

---

## Hilfe

- **Issues**: [GitHub Issues](https://github.com/NiklasJavier/SOT/issues)
- **Discussions**: [GitHub Discussions](https://github.com/NiklasJavier/SOT/discussions)

---

## Siehe auch

- [Architektur](architecture.md)
- [CLI-Referenz](cli-reference.md)
- [Konfiguration](configuration.md)
- [CONTRIBUTING.md](../CONTRIBUTING.md)
