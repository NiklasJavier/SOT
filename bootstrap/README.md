# SOT Bootstrap Module

Dieses Verzeichnis enthält die Bootstrap-Skripte für das Server Operation Toolkit.

## Dateien

| Datei | Beschreibung |
|-------|--------------|
| `init.sh` | Haupt-Bootstrap-Skript — klont Repository, generiert Config, erstellt Symlinks |
| `dependencies.sh` | Dependency-Manager — Ansible, Docker, SDKMAN! |
| `vault_template.j2` | Jinja2-Template für Vault-Initialisierung mit sicheren Defaults |

> **Hinweis:** Die CLI liegt jetzt unter `bin/sot`

## Verwendung

### Bootstrap (Remote)

```bash
curl -fsSL "https://raw.githubusercontent.com/NiklasJavier/SOT/production/bootstrap/init.sh" \
  | bash -s -- -branch production -port 22
```

### Bootstrap (Lokal)

```bash
sudo bash bootstrap/init.sh -branch dev -port 22
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
2026-01-13 18:30:00 [root] SOT bootstrap
2026-01-13 18:31:00 [root] SOT vault
```

## Architektur

```
setup_sot.sh
    │
    ├── lib/core/bootstrap/args_parser.sh    → CLI-Argumente parsen
    ├── lib/core/bootstrap/config_defaults.sh → Defaults laden
    ├── lib/core/bootstrap/tasks.sh          → Einzelne Bootstrap-Tasks
    ├── lib/core/bootstrap/config_writer.sh  → config.yaml generieren
    └── lib/core/bootstrap/runner.sh         → Task-Runner mit Progress
```

## Entwicklung

Zum Testen von Änderungen:

```bash
# Lokaler Test ohne Installation
bash bootstrap/init.sh -branch dev -port 22

# Nur Config generieren (dry-run)
DEBUG=1 bash bootstrap/init.sh -branch dev
```

## Siehe auch

- [lib/core/bootstrap/README.md](../lib/core/bootstrap/README.md) — Bootstrap-Library Dokumentation
- [CONTRIBUTING.md](../CONTRIBUTING.md) — Beitragsrichtlinien
