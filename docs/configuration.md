# SOT Konfiguration

Referenz für alle Konfigurationsoptionen.

## Konfigurationsdateien

| Datei | Beschreibung |
|-------|--------------|
| `services/default_config.yml` | Standard-Defaults (v1 Format) |
| `services/default_config_v2.yml` | Standard-Defaults (v2 Format) |
| `/etc/DevOpsToolkit/config.yaml` | Generierte Runtime-Config |
| `services/overrides/*.yml` | Umgebungsspezifische Overrides |

## Formate

### v1 — Flaches Format (Legacy)

```yaml
system_name: "SRV-EXAMPLE"
ssh_port: "282"
aat_enabled: "true"
aat_dir: "/opt/AAT"
```

### v2 — Verschachteltes Format (Empfohlen)

```yaml
system:
  name: "SRV-EXAMPLE"
  username: "__GENERATE_USERNAME__"

ssh:
  port: "282"

aat:
  enabled: "true"
  branch: "main"
```

> Der Smart-Loader konvertiert `section.key` → `section_key` automatisch.

---

## Konfigurationsschlüssel

### System

| Schlüssel | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `system_name` | string | Hostname | Server-Bezeichnung |
| `username` | string | generiert | SOT-Benutzer (11 Zeichen) |

### SSH

| Schlüssel | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `ssh_port` | string | `"22"` | SSH-Port für Firewall |
| `ssh_key` | string | — | Public Key für Zugang |

### Pfade

| Schlüssel | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `clone_dir` | string | `/etc/DevOpsToolkit` | Repository-Pfad |
| `opt_data_dir` | string | `/opt/SRV-$username` | Daten-Verzeichnis |
| `modules_dir` | string | `$clone_dir/modules` | Module-Pfad |
| `scripts_dir` | string | `$clone_dir/scripts` | Scripts-Pfad |

### Vault

| Schlüssel | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `vault_file` | string | `$opt_data_dir/vault.yml` | Vault-Datei |
| `vault_secret` | string | `$opt_data_dir/.vault_pass` | Passwort-Datei |

### Ansible

| Schlüssel | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `ansible_local_enabled` | bool | `"true"` | Lokale Playbooks nutzen |
| `ansible_local_priority` | bool | `"true"` | Lokal vor AAT priorisieren |
| `ansible_local_dir` | string | `$modules_dir/ansible` | Lokales Ansible-Verzeichnis |

### AAT Integration

| Schlüssel | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `aat_enabled` | bool | `"true"` | AAT aktivieren |
| `aat_repo_url` | string | GitHub URL | Repository-URL |
| `aat_dir` | string | `/opt/AAT` | Zielverzeichnis |
| `aat_branch` | string | `"main"` | Branch |

### TID Integration

| Schlüssel | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `tid_enabled` | bool | `"true"` | TID aktivieren |
| `tid_repo_url` | string | GitHub URL | Repository-URL |
| `tid_dir` | string | `/opt/TID` | Zielverzeichnis |
| `tid_branch` | string | `"main"` | Branch |

### Runner

| Schlüssel | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `runner_enabled` | bool | `"true"` | Runner aktivieren |
| `runner_default_mode` | string | `"ansible"` | Standard-Modus |
| `runner_sync_before_run` | bool | `"true"` | Vor Ausführung synchronisieren |

### Logging

| Schlüssel | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `log_file` | string | `/var/log/devops_commands.log` | Log-Datei |

---

## Dynamische Werte

Platzhalter werden beim Setup automatisch ersetzt:

| Platzhalter | Ersetzt durch |
|-------------|---------------|
| `__GENERATE_USERNAME__` | 11-stelliger zufälliger Benutzername |
| `__GENERATE_VAULT_SECRET__` | 32-stelliges zufälliges Passwort |
| `__DETECT_HOSTNAME__` | Aktueller Hostname |
| `__DETECT_BRANCH__` | Aktueller Git-Branch |

---

## Priorität

Werte werden in dieser Reihenfolge aufgelöst:

1. **CLI-Parameter** (`SOT setup -port 22`)
2. **Environment-Variablen** (`SSH_PORT=22`)
3. **config.yaml** (generiert)
4. **Overrides** (`services/overrides/`)
5. **Defaults** (`services/default_config.yml`)

---

## Overrides

Umgebungsspezifische Konfigurationen in `services/overrides/`:

```yaml
# services/overrides/production.yml
system_name: "PROD-SERVER"
ssh_port: "2222"
```

```yaml
# services/overrides/staging.yml
system_name: "STAGING-SERVER"
aat_branch: "develop"
```

---

## Programmatischer Zugriff

### In Bash

```bash
source "$SCRIPT_ROOT/lib/init.sh"

# Wert mit Default lesen
port=$(get_yaml_value "$CONFIG_FILE" "ssh_port" "22")

# Smart Loader (v1 und v2)
load_config "$CONFIG_FILE"
echo "${CONFIG[ssh_port]}"
```

### In Ansible

```yaml
- name: Load SOT config
  include_vars:
    file: "{{ playbook_dir }}/../../../services/default_config.yml"
    name: sot_config

- name: Use config value
  debug:
    msg: "SSH Port: {{ sot_config.ssh_port }}"
```

---

## Validierung

Konfiguration prüfen:

```bash
./ci/run-config-validation.sh
```

**Prüft:**
- ✓ YAML-Syntax
- ✓ Erforderliche Schlüssel vorhanden
- ✓ Datentypen korrekt

---

## Siehe auch

- [Architektur](architecture.md)
- [CLI-Referenz](cli-reference.md)
- [Entwicklung](development.md)
