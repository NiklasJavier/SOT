# SOT Integrations

Dieses Verzeichnis enthält Skripte zur Integration mit externen Tools und Repositories.

## Verfügbare Integrationen

| Skript | Beschreibung | SOT-Befehl |
|--------|--------------|------------|
| `aat_sync.sh` | AAT (Ansible Automation Tools) Repository synchronisieren | `SOT aat sync` |
| `tid_sync.sh` | TID (Terraform Infrastructure Deployment) Repository synchronisieren | `SOT tid sync` |
| `validate_sync.sh` | Status aller Integrationen validieren | `SOT integrations validate` |

## Konfiguration

Die Integrationen werden über `config.yaml` konfiguriert:

```yaml
# AAT Integration
aat_enabled: "true"
aat_repo_url: "https://github.com/NiklasJavier/AAT.git"
aat_dir: "/opt/AAT"
aat_branch: "main"

# TID Integration
tid_enabled: "true"
tid_repo_url: "https://github.com/NiklasJavier/TID.git"
tid_dir: "/opt/TID"
tid_branch: "main"
```

## Timeout-Konfiguration

Git-Operationen haben einen konfigurierbaren Timeout (Standard: 120 Sekunden):

```bash
# Timeout auf 5 Minuten setzen
export SOT_GIT_TIMEOUT=300
SOT aat sync
```

## AAT (Ansible Automation Tools)

AAT erweitert SOT um zusätzliche Ansible-Playbooks und -Rollen.

### Synchronisieren

```bash
# Standard-Branch aus config.yaml
SOT aat sync

# Spezifischer Branch
SOT aat sync --branch develop
```

### Erwartete Struktur

```
/opt/AAT/
├── playbooks/
│   └── site.yml     # Haupt-Playbook
└── roles/
    └── ...
```

## TID (Terraform Infrastructure Deployment)

TID bietet Terraform-Module für Infrastruktur-Provisionierung.

### Synchronisieren

```bash
# Standard-Branch aus config.yaml
SOT tid sync

# Spezifischer Branch
SOT tid sync --branch feature/new-module
```

### Erwartete Struktur

```
/opt/TID/
├── modules/
│   └── proxmox/
│       └── main.tf  # Proxmox-Modul
└── stacks/
    └── ...
```

## Validierung

Prüft, ob alle aktivierten Integrationen korrekt eingerichtet sind:

```bash
SOT integrations validate
```

### Geprüfte Punkte

- ✓ Git-Repository vorhanden
- ✓ Korrekter Branch ausgecheckt
- ✓ Erforderliche Dateien existieren

## Troubleshooting

### Sync schlägt fehl

```bash
# Debug: Manuell klonen testen
git clone --depth 1 https://github.com/NiklasJavier/AAT.git /tmp/aat-test

# Berechtigungen prüfen
ls -la /opt/
sudo mkdir -p /opt/AAT && sudo chown $USER:$USER /opt/AAT
```

### Timeout bei langsamer Verbindung

```bash
# Timeout erhöhen
export SOT_GIT_TIMEOUT=600  # 10 Minuten
SOT aat sync
```

### Branch nicht verfügbar

```bash
# Verfügbare Remote-Branches anzeigen
git ls-remote --heads https://github.com/NiklasJavier/AAT.git
```

## Entwicklung

Alle Integration-Skripte nutzen die gemeinsame Bibliothek:

```bash
# Am Anfang jedes Skripts
SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$SCRIPT_ROOT/lib/init.sh"
```

### Verfügbare Funktionen

| Funktion | Beschreibung |
|----------|--------------|
| `find_config_file_arg "$@"` | config.yaml aus Argumenten finden |
| `get_yaml_value <file> <key> <default>` | YAML-Wert auslesen |
| `is_true <value>` | Boolean prüfen |
| `run_with_timeout <secs> <cmd>` | Befehl mit Timeout ausführen |
| `info`, `warn`, `err`, `success` | Farbige Ausgabe |
