# SOT CLI-Referenz

Vollständige Referenz aller verfügbaren `SOT`-Befehle.

## Syntax

```bash
SOT [unterordner] <befehl> [optionen]
```

## Hauptbefehle

### `SOT help`

Zeigt alle verfügbaren Befehle an.

```bash
SOT help
```

---

### `SOT bootstrap`

Führt das Host-Setup-Playbook aus.

```bash
SOT bootstrap [optionen]
```

**Optionen:**
| Flag | Beschreibung |
|------|--------------|
| `--tags <tags>` | Nur bestimmte Ansible-Tags ausführen |
| `--skip-tags <tags>` | Tags überspringen |
| `--check` | Dry-Run (keine Änderungen) |

**Beispiele:**
```bash
SOT bootstrap                      # Vollständiges Bootstrap
SOT bootstrap --tags ssh,firewall  # Nur SSH und Firewall
SOT bootstrap --check              # Simulation
```

---

### `SOT vault`

Interaktive Vault-Bearbeitung.

```bash
SOT vault [aktion]
```

**Aktionen:**
| Aktion | Beschreibung |
|--------|--------------|
| (leer) | Vault im Editor öffnen |
| `view` | Vault anzeigen (read-only) |
| `rekey` | Passwort ändern |

**Beispiele:**
```bash
SOT vault           # Bearbeiten
SOT vault view      # Nur anzeigen
SOT vault rekey     # Neues Passwort
```

---

### `SOT runner`

Führt Ansible-Playbooks oder Terraform-Stacks aus.

```bash
SOT runner <typ> <name> [optionen]
```

**Typen:**
| Typ | Beschreibung |
|-----|--------------|
| `ansible` | Ansible-Playbook ausführen |
| `terraform` | Terraform-Stack ausführen |

**Beispiele:**
```bash
SOT runner ansible site.yml           # Playbook ausführen
SOT runner terraform proxmox apply    # Terraform apply
SOT runner terraform proxmox destroy  # Terraform destroy
```

---

## Integrations-Befehle

### `SOT aat sync`

Synchronisiert das AAT-Repository.

```bash
SOT aat sync [--branch <name>]
```

**Optionen:**
| Flag | Beschreibung |
|------|--------------|
| `--branch` | Spezifischen Branch auschecken |

**Environment:**
| Variable | Beschreibung | Default |
|----------|--------------|---------|
| `SOT_GIT_TIMEOUT` | Timeout für Git-Operationen | `120` |

**Beispiele:**
```bash
SOT aat sync                    # Standard-Branch aus config
SOT aat sync --branch develop   # Develop-Branch
SOT_GIT_TIMEOUT=300 SOT aat sync  # Mit 5min Timeout
```

---

### `SOT tid sync`

Synchronisiert das TID-Repository.

```bash
SOT tid sync [--branch <name>]
```

*(Gleiche Optionen wie `aat sync`)*

---

### `SOT integrations validate`

Validiert den Status aller Integrationen.

```bash
SOT integrations validate
```

**Prüft:**
- ✓ Git-Repositories vorhanden
- ✓ Korrekter Branch ausgecheckt
- ✓ Erforderliche Dateien existieren

---

## Wartungs-Befehle

### `SOT maintenance update`

Aktualisiert das lokale SOT-Repository.

```bash
SOT maintenance update
```

**Aktionen:**
1. `git fetch`
2. `git pull --rebase --autostash`

---

### `SOT maintenance delete`

Entfernt die SOT-Installation.

```bash
SOT maintenance delete
```

**Erstellt Backup:**
- Vault-Zugangsdaten werden in `$opt_data_dir` gesichert
- Ausführbares Skript zum Vault-Zugriff erstellt

**Löscht:**
- Repository (`/etc/DevOpsToolkit`)
- Symlink (`/usr/sbin/SOT`)
- Log-Datei

---

### `SOT maintenance cleanup_old_users`

Entfernt alte Test-Benutzer und bereinigt UFW-Regeln.

```bash
SOT maintenance cleanup_old_users
```

⚠️ **Warnung:** Interaktive Bestätigung erforderlich!

---

## Automatisch injizierte Parameter

Jedes Skript erhält automatisch diese Parameter:

| Position | Variable | Beschreibung |
|----------|----------|--------------|
| `$1` | command | Befehlsname |
| `$2` | config_file | Pfad zu config.yaml |
| `$3` | username | Aktueller Benutzer |
| `$4` | vault_file | Pfad zur Vault-Datei |
| `$5` | vault_secret | Vault-Passwort-Datei |
| `$6` | opt_data_dir | Daten-Verzeichnis |
| `$7` | clone_dir | Repository-Pfad |
| `$8` | systemlink_path | Symlink-Pfad |
| `$9` | log_file | Log-Datei Pfad |
| `$10` | branch | Aktueller Branch |

---

## Exit-Codes

| Code | Bedeutung |
|------|-----------|
| `0` | Erfolg |
| `1` | Allgemeiner Fehler |
| `2` | Ungültige Argumente |
| `124` | Timeout (bei Git-Operationen) |

---

## Logging

Alle Befehle werden protokolliert:

```
/var/log/devops_commands.log
```

Format:
```
2026-01-13 18:30:00 [root] SOT bootstrap
2026-01-13 18:31:00 [root] SOT vault
```

---

## Siehe auch

- [Architektur](architecture.md)
- [Konfiguration](configuration.md)
- [Entwicklung](development.md)
