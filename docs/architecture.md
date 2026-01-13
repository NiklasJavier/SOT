# SOT Architektur

Dieses Dokument beschreibt die Architektur des Server Operation Toolkits.

## Übersicht

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SOT CLI (SOT <cmd>)                        │
│                              bin/sot                                │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Shared Library (lib/)                          │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ core/              cli/              plugins/                │   │
│  │ colors.sh          registry.sh       manager.sh             │   │
│  │ yaml_parser.sh     integrations.sh                          │   │
│  │ helpers.sh                                                  │   │
│  │ bootstrap/*                                                 │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   commands/     │  │   modules/      │  │   config/       │
│   bootstrap.sh  │  │   ansible/      │  │   config.yaml   │
│   vault.sh      │  │   docker/       │  │   overrides/    │
│   runner.sh     │  │   sdkman/       │  │                 │
│   integrations/ │  └─────────────────┘  └─────────────────┘
│   maintenance/  │
└─────────────────┘
```

## Komponenten

### 1. CLI Layer (`bin/sot`)

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
| `bootstrap/*` | Modulare Bootstrap-Logik |

### 3. Commands (`commands/`)

CLI-Befehle, organisiert nach Funktion:

```
commands/
├── bootstrap.sh       # SOT bootstrap
├── vault.sh           # SOT vault
├── runner.sh          # SOT runner ansible/terraform
├── integrations/      # SOT aat sync, tid sync
└── maintenance/       # SOT update, delete
```

### 4. Module (`modules/`)

Installierbare Komponenten:

| Modul | Beschreibung |
|-------|--------------|
| `ansible/` | Playbooks, Rollen, Inventory |
| `docker/` | Docker-Installation, Compose-Templates |
| `sdkman/` | SDKMAN!-Installation |

### 5. Services/Config (`config/`)

Konfigurationsdateien:

```
config/
├── default_config.yml      # v1 Format (flach)
├── default_config_v2.yml   # v2 Format (verschachtelt)
└── overrides/              # Umgebungsspezifisch
```

## Datenfluss

### Setup-Prozess

```
1. curl init.sh | bash
        │
        ▼
2. setup_sot.sh
   ├── Clone Repository → /etc/DevOpsToolkit
   ├── Load defaults    → config/default_config.yml
   ├── Generate config  → config.yaml
   ├── Create symlink   → /usr/sbin/SOT
   └── Run bootstrap.sh → Ansible Playbook
```

### CLI-Aufruf

```
SOT vault
    │
    ▼
bin/sot
    │
    ├── 1. Parse config.yaml
    ├── 2. Find commands/vault.sh
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
mkdir -p modules/mymodule/{commands,hooks}
cat > modules/mymodule/install.sh <<'EOF'
#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/init.sh"
info "Installing mymodule..."
EOF
chmod +x modules/mymodule/install.sh
```

### Neuen CLI-Befehl hinzufügen

```bash
cat > commands/mycommand.sh <<'EOF'
#!/usr/bin/env bash
source "$(dirname "$0")/../lib/init.sh"
info "Running mycommand..."
EOF
chmod +x commands/mycommand.sh
# Aufruf: SOT mycommand
```

## Siehe auch

- [CLI-Referenz](cli-reference.md)
- [Konfiguration](configuration.md)
- [Entwicklung](development.md)
