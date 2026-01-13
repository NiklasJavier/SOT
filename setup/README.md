# SOT Setup Module

Dieses Verzeichnis enthält die Bootstrap-Skripte für das Server Operation Toolkit.

## Dateien

| Datei | Beschreibung |
|-------|--------------|
| `setup_sot.sh` | Haupt-Bootstrap-Skript — klont Repository, generiert Config, erstellt Symlinks |
| `install_tools.sh` | Tool-Installations-Manager — Ansible, Docker, SDKMAN! |
| `vault_template.j2` | Jinja2-Template für Vault-Initialisierung mit sicheren Defaults |

> **Hinweis:** Die CLI liegt jetzt unter `bin/sot`

## Verwendung

### Bootstrap (Remote)

```bash
curl -fsSL "https://raw.githubusercontent.com/NiklasJavier/SOT/production/setup/setup_sot.sh" \
  | bash -s -- -branch production -port 22
```

### Bootstrap (Lokal)

```bash
sudo bash setup/setup_sot.sh -branch dev -port 22
```

### Setup-Flags

| Flag | Beschreibung |
|------|--------------|
| `-branch <name>` | Branch für Installation (production, staging, dev) |
| `-port <nummer>` | SSH-Port für Firewall-Konfiguration |
| `-config <pfad>` | Alternative Default-Config laden |
| `-systemname <name>` | Systemname überschreiben |
| `-key <pubkey>` | SSH Public Key speichern |
| `-tools <liste>` | Zu installierende Tools (space-separated) |
| `-aat_enabled <bool>` | AAT-Integration aktivieren |
| `-tid_enabled <bool>` | TID-Integration aktivieren |

## CLI-Nutzung

Der Einstiegspunkt für alle `SOT`-Befehle liegt in `bin/sot`:

```bash
SOT [unterordner] <befehl> [optionen]
```

### Automatisch injizierte Parameter

Jedes aufgerufene Skript erhält automatisch:

- `$1` — Befehlsname
- `$2` — Config-Datei Pfad
- `$3` — Username
- `$4` — Vault-Datei Pfad
- `$5` — Vault-Secret
- `$6` — Opt-Data-Verzeichnis
- `$7` — Clone-Verzeichnis
- `$8` — Symlink-Pfad
- `$9` — Log-Datei
- `$10` — Branch

### Logging

Alle CLI-Aufrufe werden in `log_file` (Standard: `/var/log/devops_commands.log`) protokolliert:

```
2026-01-13 18:30:00 [root] SOT setup
2026-01-13 18:31:00 [root] SOT vault
```

## Architektur

```
setup_sot.sh
    │
    ├── lib/setup/args_parser.sh    → CLI-Argumente parsen
    ├── lib/setup/config_defaults.sh → Defaults laden
    ├── lib/setup/tasks.sh          → Einzelne Setup-Tasks
    ├── lib/setup/config_writer.sh  → config.yaml generieren
    └── lib/setup/runner.sh         → Task-Runner mit Progress
```

## Entwicklung

Zum Testen von Änderungen:

```bash
# Lokaler Test ohne Installation
bash setup/setup_sot.sh -branch dev -port 22

# Nur Config generieren (dry-run)
DEBUG=1 bash setup/setup_sot.sh -branch dev
```

## Siehe auch

- [lib/setup/README.md](../lib/setup/README.md) — Setup-Library Dokumentation
- [CONTRIBUTING.md](../CONTRIBUTING.md) — Beitragsrichtlinien
