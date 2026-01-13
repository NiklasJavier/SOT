# SOT Architektur

Dieses Dokument beschreibt die Architektur des Server Operation Toolkits.

## Übersicht

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SOT CLI (SOT <cmd>)                        │
│                        setup/cli_wrapper.sh                         │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Shared Library (lib/)                          │
│  ┌──────────┐  ┌──────────────┐  ┌───────────┐  ┌────────────────┐  │
│  │ colors   │  │ yaml_parser  │  │  helpers  │  │ setup/*        │  │
│  │ .sh      │  │    .sh       │  │   .sh     │  │ (5 modules)    │  │
│  └──────────┘  └──────────────┘  └───────────┘  └────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   scripts/      │  │   modules/      │  │   services/     │
│   commands/     │  │   ansible/      │  │   config.yaml   │
│   integrations/ │  │   docker/       │  │   overrides/    │
│   maintenance/  │  │   sdkman/       │  │                 │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

## Komponenten

### 1. CLI Layer (`setup/cli_wrapper.sh`)

Der Einstiegspunkt für alle `SOT`-Befehle:

```bash
SOT [unterordner] <befehl> [optionen]
```

**Aufgaben:**
- Befehlsauflösung (findet das passende Skript)
- Parameter-Injektion (config, vault, paths)
- Logging aller Aufrufe

### 2. Shared Library (`lib/`)

Wiederverwendbare Bash-Funktionen:

| Modul | Funktion |
|-------|----------|
| `colors.sh` | Terminal-Farben, semantische Aliase |
| `yaml_parser.sh` | YAML v1/v2 Parser, `get_yaml_value()`, `load_config()` |
| `helpers.sh` | `is_true()`, `info()`, `err()`, `run_with_timeout()` |
| `setup/*` | Modulare Setup-Logik |

### 3. Scripts (`scripts/`)

CLI-Befehle, organisiert nach Funktion:

```
scripts/
├── setup.sh           # SOT setup
├── vault.sh           # SOT vault
├── runner.sh          # SOT runner ansible/terraform
├── integrations/      # SOT aat sync, tid sync
└── maintenance/       # SOT maintenance update/delete
```

### 4. Module (`modules/`)

Installierbare Komponenten:

| Modul | Beschreibung |
|-------|--------------|
| `ansible/` | Playbooks, Rollen, Inventory |
| `docker/` | Docker-Installation, Compose-Templates |
| `sdkman/` | SDKMAN!-Installation |

### 5. Services/Config (`services/`)

Konfigurationsdateien:

```
services/
├── default_config.yml      # v1 Format (flach)
├── default_config_v2.yml   # v2 Format (verschachtelt)
└── overrides/              # Umgebungsspezifisch
```

## Datenfluss

### Setup-Prozess

```
1. curl setup_sot.sh | bash
        │
        ▼
2. setup_sot.sh
   ├── Clone Repository → /etc/DevOpsToolkit
   ├── Load defaults    → services/default_config.yml
   ├── Generate config  → config.yaml
   ├── Create symlink   → /usr/sbin/SOT
   └── Run setup.sh     → Ansible Playbook
```

### CLI-Aufruf

```
SOT vault
    │
    ▼
cli_wrapper.sh
    │
    ├── 1. Parse config.yaml
    ├── 2. Find scripts/vault.sh
    ├── 3. Inject parameters
    ├── 4. Log to log_file
    └── 5. Execute script
```

## Konfiguration

### Smart Config Loader

```bash
load_config "/path/to/config.yaml"

# Lädt automatisch:
# - v1 (flach):      key: value
# - v2 (verschachtelt): section.key: value → section_key

get_config_value "ssh_port" "22"  # Funktioniert mit beiden Formaten
```

### Priorität

1. CLI-Parameter (`-port 22`)
2. Environment (`SSH_PORT=22`)
3. config.yaml
4. defaults

## Sicherheit

### Vault-Handling

```
┌──────────────────┐     ┌──────────────────┐
│  Vault Secret    │────▶│  /dev/shm/       │
│  (ansible-vault) │     │  (RAM-basiert)   │
└──────────────────┘     └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │  shred -u -z     │
                         │  (sichere        │
                         │   Löschung)      │
                         └──────────────────┘
```

## Erweiterbarkeit

### Neues Modul hinzufügen

```bash
mkdir -p modules/mymodule
cat > modules/mymodule/install.sh <<'EOF'
#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/init.sh"
info "Installing mymodule..."
EOF
chmod +x modules/mymodule/install.sh
```

### Neuen CLI-Befehl hinzufügen

```bash
cat > scripts/mycommand.sh <<'EOF'
#!/usr/bin/env bash
source "$(dirname "$0")/../lib/init.sh"
info "Running mycommand..."
EOF
chmod +x scripts/mycommand.sh
# Aufruf: SOT mycommand
```

## Siehe auch

- [CLI-Referenz](cli-reference.md)
- [Konfiguration](configuration.md)
- [Entwicklung](development.md)
