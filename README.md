# SOT — Server Operation Toolkit

![License](https://img.shields.io/badge/license-MIT-blue.svg) ![Shell](https://img.shields.io/badge/shell-bash-121011.svg?logo=gnu-bash&logoColor=white) ![Ansible](https://img.shields.io/badge/automation-ansible-EE0000.svg?logo=ansible&logoColor=white) ![Docker](https://img.shields.io/badge/containers-docker-2496ED.svg?logo=docker&logoColor=white)


Das Repository stellt ein leichtgewichtiges DevOps-Toolkit bereit, mit dem sich Entwicklungs-, Staging- und Produktionsumgebungen auf einem Host schnell initialisieren, automatisieren und verwalten lassen. Kernstück ist das `devops` CLI, das Skripte strukturiert ausführt, Logs schreibt und eine Ansible-Vault-gestützte Konfiguration nutzt.


### Architektur (Mermaid)

```mermaid
flowchart TD
    subgraph SOT["SOT — Server Operation Toolkit"]
        CLI["devops CLI\n(environments/devops_cli.sh)"]
        CFG["config.yaml\n(environments/<branch>/.settings)"]
        VLT["Vault (Ansible Vault)"]
        LOG["Logging\n/var/log/devops_commands.log"]
        CLI --> CFG
        CLI --> VLT
        CLI --> LOG
    end

    subgraph AAT["AAT — Ansible Automation Tools\n(https://github.com/NiklasJavier/AAT)"]
        APL["Playbooks / Rollen / Inventories"]
        AATDIR["Pfad: aat_dir (z. B. /opt/AAT)"]
        APL --> AATDIR
    end

    subgraph TID["TID — Terraform Infrastructure Deployment\n(https://github.com/NiklasJavier/TID)"]
        MOD["Module / services/*.tfvars / env"]
        TIDDIR["Pfad: tid_dir (z. B. /opt/TID)"]
        MOD --> TIDDIR
    end

    CLI -- "devops aat sync" --> AAT
    CLI -- "devops tid sync" --> TID
    CLI -- "ansible-playbook ..." --> APL
    CLI -- "terraform init/plan/apply" --> MOD

    note over SOT: setup_devops_toolkit.sh\n-klont/aktualisiert Repo\n-schreibt config.yaml\n-verlinkt devops
```

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

- [Überblick](#überblick)
- [Verzeichnisstruktur (Auszug)](#verzeichnisstruktur-auszug)
- [Schnellstart (Einzeiler)](#schnellstart-einzeiler)
- [Installation & Flags](#installation--flags)
- [`devops` CLI: Nutzung & Verhalten](#devops-cli-nutzung--verhalten)
- [Konfiguration (`config.yaml`)](#konfiguration-configyaml)
- [AAT-Integration (zentrales Ansible-Repo)](#aat-integration-zentrales-ansible-repo)
 - [TID-Integration (Terraform-Repo)](#tid-integration-terraform-repo)
- [Ansible Vault](#ansible-vault)
- [Wichtige Skripte (Auszug)](#wichtige-skripte-auszug)
- [Tools: Ansible & Docker-Vorlagen](#tools-ansible--docker-vorlagen)
- [Beispiele](#beispiele)
- [Sicherheit, CI/CD, Monitoring](#sicherheit-cicd-monitoring)

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

## AAT-Integration (zentrales Ansible-Repo)

SOT kann optional automatisch auf das zentrale Ansible-Repository AAT verweisen und es bereitstellen. Standardwerte sind bereits gesetzt und können beim Setup überschrieben werden.

- Repo: [`NiklasJavier/AAT`](https://github.com/NiklasJavier/AAT)
- Default-Konfiguration (in `config.yaml`):
  - `aat_enabled: "true"`
  - `aat_repo_url: "https://github.com/NiklasJavier/AAT.git"`
  - `aat_dir: "/opt/AAT"`

### Setup-Flags für AAT

```bash
# URL, Zielpfad, Aktivierung steuern
curl -fsSL https://raw.githubusercontent.com/NiklasJavier/SOT/dev/environments/setup_devops_toolkit.sh \
  | bash -s -- -branch dev -aat_url "https://github.com/NiklasJavier/AAT.git" -aat_dir "/opt/AAT" -aat_enabled true
```

Bei aktivierter Integration wird AAT während des Setups geklont bzw. aktualisiert und die Pfade in `config.yaml` hinterlegt. Anschließend können Ansible-Playbooks/Rollen aus AAT direkt referenziert werden (z. B. via `ansible-playbook -i "$aat_dir/inventory/..." "$aat_dir/playbooks/..."`).

## TID-Integration (Terraform-Repo)

SOT kann optional das Terraform-Repository TID (Proxmox/Hetzner-Deployment) bereitstellen und aktuell halten.

- Repo: [`NiklasJavier/TID`](https://github.com/NiklasJavier/TID)
- Default-Konfiguration (in `config.yaml`):
  - `tid_enabled: "true"`
  - `tid_repo_url: "https://github.com/NiklasJavier/TID.git"`
  - `tid_dir: "/opt/TID"`

### Setup-Flags für TID

```bash
curl -fsSL https://raw.githubusercontent.com/NiklasJavier/SOT/dev/environments/setup_devops_toolkit.sh \
  | bash -s -- -branch dev -tid_url "https://github.com/NiklasJavier/TID.git" -tid_dir "/opt/TID" -tid_enabled true
```

### Nutzung

- Repo synchronisieren:
  ```bash
  devops tid sync
  ```
- Beispiel (im TID-Verzeichnis, je nach Konfiguration):
  ```bash
  cd "$tid_dir" && terraform init && terraform plan
  ```

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

# AAT synchronisieren (holt/aktualisiert zentrales Ansible-Repo laut config.yaml)
devops aat sync
```

### Robustheit im Setup

- Automatische Paketmanager-Erkennung für Git-Installation (apt, dnf, yum, pacman, zypper, apk, brew)
- Git-Operationen mit Retry und optionalem Shallow Clone

## Sicherheit, CI/CD, Monitoring

Weitere Hinweise sind in `docs/` vorgesehen (`Security.md`, `CI_CD.md`, `Monitoring.md`, `Introduction.md`). Falls noch leer, bitte projekt-/umgebungsspezifisch ergänzen.

---

© Lizenz siehe `LICENSE`.
