# SOT — Server Operation Toolkit

Das Repository stellt ein leichtgewichtiges DevOps-Toolkit bereit, mit dem sich Entwicklungs-, Staging- und Produktionsumgebungen auf einem Host schnell initialisieren, automatisieren und verwalten lassen. Kernstück ist das `devops` CLI, das Skripte strukturiert ausführt, Logs schreibt und eine Ansible-Vault-gestützte Konfiguration nutzt.

## Kurzüberblick (Cheat Sheet)

- Ziel: Einheitliches Setup/Operate-CLI (`devops`) mit Logging und sicherer Parameterverwaltung (Ansible Vault)
- Setup: `environments/setup_devops_toolkit.sh` klont nach `/etc/DevOpsToolkit`, erzeugt `config.yaml`, verlinkt `/usr/sbin/devops`
- CLI: `devops [ordner] <kommando> [args]`, `devops help | cat`, Logging nach `log_file`
- Config: `environments/<branch>/.settings/config.yaml` (u. a. `system_name`, `ssh_port`, `opt_data_dir`, `vault_*`)
- Vault: `devops vault` und `${opt_data_dir}/openVault.sh`, Secret sicher verwahren/entfernen
- Wichtige Kommandos: `devops setup`, `devops debug update`, `devops debug delete`
- Ansible/Docker: Playbooks unter `tools/ansible/...`, Templates unter `tools/docker/templates/...`
- Schnellstart:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/NiklasJavier/SOT/dev/environments/setup_devops_toolkit.sh | bash -s -- -branch dev -port "22" && devops setup
  ```

## Inhalt

- **Überblick**
- **Verzeichnisstruktur**
- **Schnellstart (Einzeiler)**
- **Installation & Flags**
- **`devops` CLI: Nutzung & Verhalten**
- **Konfiguration (`config.yaml`)**
- **Ansible Vault**
- **Wichtige Skripte**
- **Tools: Ansible & Docker-Vorlagen**
- **Beispiele**
- **Sicherheit, CI/CD, Monitoring**

## Überblick

- **Ziel**: Einheitlicher Setup- und Betriebs-Workflow über ein CLI, inkl. Protokollierung und sicherer Parameterverwaltung.
- **Ablauf**: Setup-Skript installiert/aktualisiert das Toolkit, schreibt eine Branch-spezifische Konfiguration und registriert das CLI unter `devops`.
- **Konfiguration**: Zentral in einer `config.yaml` je Branch unter `environments/<branch>/.settings/` mit Parametern wie Systemname, SSH-Port, Pfade, Log-Level und Vault.

## Verzeichnisstruktur (Auszug)

```text
environments/
  devops_cli.sh            # CLI Wrapper, wird als /usr/sbin/devops verlinkt
  setup_devops_toolkit.sh  # Setup-/Bootstrap-Skript
  install_tools.sh         # Installation konfigurierter Tools (z. B. ansible, docker)
  vault_content.j2         # Template für Vault-Startinhalt
scripts/
  setup.sh                 # Allgemeines Setup (über devops ausführbar)
  vault.sh                 # Vault-Interaktionen
  debug/
    delete.sh              # Aufräumen/Deinstallieren
    update.sh              # Toolkit aktualisieren
tools/
  ansible/
    host/                  # Host-Playbooks/Rollen
    container/             # Container-Playbooks/Rollen
  docker/templates/        # Compose/Dockerfile Templates (traefik, portainer, grafana)
```

## Schnellstart (Einzeiler)

Initialisiert das Toolkit und führt anschließend das `setup`-Kommando aus:

```bash
curl -fsSL https://raw.githubusercontent.com/NiklasJavier/SOT/dev/environments/setup_devops_toolkit.sh | bash -s -- -branch dev -port "22" && devops setup
```

Hinweise:
- Der Einzeiler lädt das Setup-Skript aus diesem Repository und startet es mit Flags (siehe unten).
- Das Setup-Skript klont intern das Toolkit-Repo nach `/etc/DevOpsToolkit` und verlinkt `environments/devops_cli.sh` nach `/usr/sbin/devops`.

## Installation & Flags

Beispiele nach Zielumgebung:

```bash
# Produktion
curl -fsSL https://raw.githubusercontent.com/NiklasJavier/SOT/dev/environments/setup_devops_toolkit.sh | bash -s -- -branch production

# Staging
curl -fsSL https://raw.githubusercontent.com/NiklasJavier/SOT/dev/environments/setup_devops_toolkit.sh | bash -s -- -branch staging

# Entwicklung
curl -fsSL https://raw.githubusercontent.com/NiklasJavier/SOT/dev/environments/setup_devops_toolkit.sh | bash -s -- -branch dev

# Entwicklung + SSH-Key
curl -fsSL https://raw.githubusercontent.com/NiklasJavier/SOT/dev/environments/setup_devops_toolkit.sh | bash -s -- -branch dev -key "ssh-pub-key"
```

Verfügbare Flags im Setup:
- `-branch [production|staging|dev]`: setzt Ziel-Branch und `use_defaults=true`.
- `-full [true|false]`: optionaler Voll-Setup.
- `-systemname <Name>`: Systemname.
- `-username <Name>`: Benutzername.
- `-key <SSH-Public-Key>`: aktiviert SSH-Key-Funktion und setzt Key.
- `-port <Port>`: SSH-Port.
- `-tools "ansible docker ..."`: zusätzliche Tools installieren.

## `devops` CLI: Nutzung & Verhalten

Aufrufschema:

```bash
devops [ordner] <kommando> [args]
```

Eigenschaften:
- Liest `config.yaml` und exportiert die Werte als Variablen.
- Listet verfügbare Kommandos über `devops help` (Scan von `scripts/`).
- Führt Skripte aus `scripts/` oder `scripts/<ordner>/` aus und übergibt Standardargumente, u. a.: `tools_dir`, `CONFIG_FILE`, `username`, `vault_file`, `vault_secret`, `opt_data_dir`, `clone_dir`, `systemlink_path`, `log_file`, `branch`.
- Schreibt Befehlslogs nach `log_file` (Standard: `/var/log/devops_commands.log`).
- Fallback auf `help`, wenn ein Kommando nicht gefunden wird.

Beispiel:

```bash
devops debug update
```

## Konfiguration (`config.yaml`)

Wird vom Setup unter `environments/<branch>/.settings/config.yaml` erstellt. Wichtige Schlüssel:
- `system_name`, `username`
- `ssh_port`
- `log_level` (debug|info|warn|error), `log_file`
- `opt_data_dir`, `tools_dir`, `scripts_dir`, `pipelines_dir`
- `tools` (z. B. "ansible docker")
- `ssh_key_function_enabled`, `ssh_key_public`
- `systemlink_path`
- `vault_file`, `vault_secret`, `vault_content`, `vault_mail`
- `clone_dir`, `branch`

## Ansible Vault

- Beim Setup wird ein Vault unter `vault_file` angelegt; der Zugriffsschlüssel steht in `vault_secret` und kann einmalig gesichert werden.
- Optional wird eine Datei `devopsVaultAccessSecret-<username>.yml` im `opt_data_dir` erzeugt (nur bei sauberem Entfernen via `devops debug delete`).
- Verwaltung über Skripte, z. B.:

```bash
devops vault
${opt_data_dir}/openVault.sh   # öffnet Vault mit gesichertem Key
```

Empfehlung: Key sicher speichern und nach Setup entfernen.

## Wichtige Skripte (Auszug)

- `scripts/setup.sh`: allgemeines Setup nach der Initialisierung.
- `scripts/vault.sh`: Vault-Ansicht/Bearbeitung.
- `scripts/debug/delete.sh`: Aufräumen des Toolkits (Entfernen, Backup der Secrets im `opt_data_dir`).
- `scripts/debug/update.sh`: Aktualisiert das Toolkit, behält eigene Anpassungen.

Ausführung jeweils über `devops`:

```bash
devops setup
devops vault
devops debug delete
devops debug update
```

## Tools: Ansible & Docker-Vorlagen

- Ansible-Playbooks und Rollen für Hosts und Container unter `tools/ansible/host` und `tools/ansible/container` (jeweils mit `ansible.cfg`, `hosts.ini`, `playbooks/`, `roles/`).
- Docker-Templates unter `tools/docker/templates/` für `traefik`, `portainer`, `grafana` (jeweils `Dockerfile` + `docker-compose.yml`).

## Beispiele

```bash
# Nach Setup alle verfügbaren Kommandos anzeigen
devops help | cat

# Beispiel: Traefik-Template prüfen/bereitstellen (manuell anpassen und deployen)
ls "$tools_dir/docker/templates/traefik" | cat

# Ansible-Host-Playbook starten (Beispiel-Datei anpassen)
ansible-playbook -i "$tools_dir/ansible/host/hosts.ini" "$tools_dir/ansible/host/playbooks/host_setup.yml"
```

## Sicherheit, CI/CD, Monitoring

Weitere Hinweise sind in `docs/` vorgesehen (`Security.md`, `CI_CD.md`, `Monitoring.md`, `Introduction.md`). Falls noch leer, bitte projekt-/umgebungsspezifisch ergänzen.

---

© Lizenz siehe `LICENSE`.
