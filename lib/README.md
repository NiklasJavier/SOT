# SOT Shared Library

Dieses Verzeichnis enthält gemeinsam genutzte Bash-Bibliotheken für das SOT-Projekt.

## Schnellstart

```bash
#!/usr/bin/env bash
source "/etc/DevOpsToolkit/lib/init.sh"

# Jetzt sind alle Funktionen verfügbar
info "Script gestartet"
```

## Module

### `init.sh` — Hauptlader

Lädt alle Bibliothekskomponenten in der richtigen Reihenfolge:
1. `colors.sh` — Farbdefinitionen
2. `yaml_parser.sh` — YAML-Parser
3. `helpers.sh` — Hilfsfunktionen

Setzt außerdem `$SOT_ROOT` und `$SOT_LIB_DIR`.

### `colors.sh` — Farbdefinitionen

```bash
# Grundfarben
echo -e "${GREEN}Erfolg${NC}"
echo -e "${RED}Fehler${NC}"
echo -e "${YELLOW}Warnung${NC}"
echo -e "${BLUE}Info${NC}"

# Weitere: $PINK, $CYAN, $GREY, $BOLD

# Semantische Aliase
$COLOR_SUCCESS   # = $GREEN
$COLOR_ERROR     # = $RED
$COLOR_WARNING   # = $YELLOW
$COLOR_INFO      # = $BLUE
$COLOR_HIGHLIGHT # = $PINK
$COLOR_MUTED     # = $GREY
```

### `yaml_parser.sh` — YAML-Parser

#### Flaches YAML (Format v1)

```bash
# config.yml:
# system_name: "SRV-EXAMPLE"
# ssh_port: "282"

declare -A config
parse_yaml_to_array "config.yml" config
echo "${config[system_name]}"  # → SRV-EXAMPLE

# Einzelwert abrufen
port=$(get_yaml_value "config.yml" "ssh_port")
```

#### Verschachteltes YAML (Format v2)

```bash
# config_v2.yml:
# system:
#   name: "SRV-EXAMPLE"
# ssh:
#   port: "282"

declare -A nested
parse_nested_yaml "config_v2.yml" nested
echo "${nested[system.name]}"  # → SRV-EXAMPLE

# Mit get_nested_value
value=$(get_nested_value nested "ssh.port")
```

#### Smart-Loader (empfohlen)

```bash
# Erkennt Format automatisch und konvertiert zu flachen Keys
declare -A config
load_config "config.yml" config

# Funktioniert mit beiden Formaten!
# section.key → section_key
echo "${config[system_name]}"  # Funktioniert mit v1 UND v2
```

### `helpers.sh` — Hilfsfunktionen

```bash
# Boolean-Prüfung
is_true "yes"   # true für: true, TRUE, 1, yes, YES, on, ON
is_false "no"   # true für: false, FALSE, 0, no, NO, off, OFF, ""

# Ausgabe-Funktionen
info "Information"     # Blau
success "Erledigt"     # Grün
warn "Achtung"         # Gelb
err "Fehler"           # Rot (nach stderr)

# Verzeichnis-Operationen
ensure_dir "/path/to/dir"  # mkdir -p mit Fehlerbehandlung

# Pfad-Auflösung
abs_path=$(resolve_path "./relative/path")

# Logging
log_command "apt update"  # Loggt mit Timestamp
```

## Setup-Bibliothek (`setup/`)

Für das Setup-Script gibt es zusätzliche Module:

```bash
source "/etc/DevOpsToolkit/lib/setup/init.sh"
```

| Modul | Beschreibung |
|-------|--------------|
| `args_parser.sh` | CLI-Argumentenverarbeitung |
| `config_defaults.sh` | Konfigurationsstandards laden |
| `tasks.sh` | Setup-Aufgaben (Clone, Symlinks) |
| `config_writer.sh` | Config-Datei generieren |
| `runner.sh` | Task-Runner mit Fortschrittsanzeige |

## Idempotenz

Alle Module können mehrfach gesourced werden ohne Seiteneffekte:

```bash
source lib/init.sh
source lib/init.sh  # Kein Problem
source lib/init.sh  # Wird übersprungen
```

## Entwicklung

### Neues Modul hinzufügen

1. Erstelle `lib/my_module.sh`:

```bash
#!/usr/bin/env bash
# Guard against multiple sourcing
[[ -n "${_MY_MODULE_LOADED:-}" ]] && return 0
_MY_MODULE_LOADED=1

my_function() {
    echo "Hello from my_module"
}
```

2. Füge zu `lib/init.sh` hinzu:

```bash
source "$SOT_LIB_DIR/my_module.sh"
```

3. Schreibe Tests unter `ci/run-my-module-tests.sh`

### Portabilität

- Teste auf macOS (BSD) und Linux (GNU)
- Verwende `openssl rand` statt `tr < /dev/urandom` für Zufallswerte
- Setze `LC_ALL=C` wenn `tr` mit Zeichenklassen verwendet wird
