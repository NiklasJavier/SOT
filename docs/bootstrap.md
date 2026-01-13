# SOT Bootstrap Installation

## Übersicht

Das SOT Bootstrap-System installiert und konfiguriert das Server Operation Toolkit automatisch. Es bietet zwei Modi:

- **Normal-Modus**: Zeigt eine übersichtliche Progress Bar mit Schritt-Informationen
- **Debug-Modus**: Zeigt detaillierte Ausgaben aller Befehle und Tasks

## Installation

### Remote Installation (empfohlen)

```bash
curl -fsSL "https://raw.githubusercontent.com/NiklasJavier/SOT/production/bootstrap/init.sh" | bash
```

Mit Debug-Ausgabe:

```bash
curl -fsSL "https://raw.githubusercontent.com/NiklasJavier/SOT/production/bootstrap/init.sh" | bash -s -- --debug
```

### Lokale Installation

```bash
sudo ./bootstrap/init.sh
```

Mit Debug-Ausgabe:

```bash
sudo ./bootstrap/init.sh --debug
```

## Optionen

| Option | Beschreibung | Beispiel |
|--------|--------------|----------|
| `-branch <name>` | Branch zum Installieren | `-branch production` |
| `-systemname <name>` | Systemname | `-systemname web-server-01` |
| `-username <name>` | Benutzername | `-username admin` |
| `-port <number>` | SSH Port | `-port 22` |
| `-tools <list>` | Zu installierende Tools | `-tools "ansible docker sdkman"` |
| `-key <pubkey>` | SSH Public Key | `-key "ssh-rsa AAAA..."` |
| `-aat_enabled true\|false` | AAT Integration aktivieren | `-aat_enabled true` |
| `-tid_enabled true\|false` | TID Integration aktivieren | `-tid_enabled true` |
| `-config <path>` | Pfad zur Config-Datei | `-config /path/to/config.yml` |
| `--debug` | Debug-Modus aktivieren | `--debug` |

## Modi im Detail

### Normal-Modus (Standard)

Der Normal-Modus zeigt eine kompakte Progress Bar:

```
  ╔══════════════════════════════════════════════════════════════╗
  ║          SOT Bootstrap - Installation läuft...           ║
  ╚══════════════════════════════════════════════════════════╝

  [████████████████████████░░░░░░░░░░░░░░░░] 60% Installiere Dependencies ✓

  ╔══════════════════════════════════════════════════════════════╗
  ║  ✓ Installation erfolgreich abgeschlossen                 ║
  ║  Dauer: 3 Minute(n) 42 Sekunde(n)                         ║
  ║  Log: /tmp/sot-bootstrap-12345.log
  ╚══════════════════════════════════════════════════════════════╝
```

**Eigenschaften:**
- Kompakte, übersichtliche Ausgabe
- Progress Bar mit Prozentwert
- Alle Befehle werden in Log-Datei geschrieben
- Zeigt nur kritische Informationen

**Log-Datei:** `/tmp/sot-bootstrap-<pid>.log`

### Debug-Modus

Der Debug-Modus zeigt alle Details:

```
  ╔══════════════════════════════════════════════════════════════╗
  ║      SOT Bootstrap - Installation (Debug-Modus)        ║
  ╚══════════════════════════════════════════════════════════════╝

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [1/11] Prüfe Verzeichnisstruktur
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Settings directory does not exist: /opt/SOT/production/.settings

  ✓ Erfolgreich

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [2/11] Zeige Konfigurationsübersicht
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      ____            ____
     / __ \\___ _   __/ __ \\____  _____
    / / / / _ \\ | / / / / / __ \\/ ___/
   / /_/ /  __/ |/ / /_/ / /_/ (__  )
  /_____/\\___/|___/\\____/ .___/____/
                       /_/

  Branch: production
  Tools: ansible docker sdkman
  ...
```

**Eigenschaften:**
- Vollständige Befehlsausgabe
- Zeigt alle Git-Operationen
- Zeigt alle Konfigurationsparameter
- Ideal für Fehlersuche

## Beispiele

### Standard-Installation

```bash
curl -fsSL "https://raw.githubusercontent.com/NiklasJavier/SOT/production/bootstrap/init.sh" | bash
```

### Installation mit Custom-Parametern

```bash
curl -fsSL "https://raw.githubusercontent.com/NiklasJavier/SOT/production/bootstrap/init.sh" | \
  bash -s -- \
  -systemname web-01 \
  -username deploy \
  -port 22 \
  -tools "ansible docker"
```

### Debug-Installation bei Problemen

```bash
sudo ./bootstrap/init.sh --debug 2>&1 | tee bootstrap-debug.log
```

## Installation Tasks

Das Bootstrap-System führt folgende Tasks aus:

1. **Prüfe Verzeichnisstruktur** - Stellt sicher, dass keine vorherige Installation existiert
2. **Zeige Konfigurationsübersicht** - (nur Debug) Zeigt alle Parameter
3. **Prüfe Root-Berechtigungen** - Stellt sicher, dass als Root ausgeführt wird
4. **Klone Repository** - Lädt SOT von GitHub
5. **Erstelle Einstellungsordner** - Legt Branch-spezifische Ordner an
6. **Konfiguriere CLI** - Setzt SOT_ROOT und CONFIG_FILE in bin/sot
7. **Erstelle CLI-Symlink** - Erstellt /usr/sbin/sot → bin/sot
8. **Setze Ausführungsrechte** - Macht Scripts ausführbar
9. **Schreibe Konfigurationsdatei** - Erstellt config.yaml
10. **Installiere Dependencies** - Installiert Ansible, Docker, SDKMAN!
11. **Zeige Abschlussübersicht** - (nur Debug) Zeigt finale Konfiguration

## Nach der Installation

### Extensions installieren

```bash
sot ex install aat  # Azure Automation Toolkit
sot ex install tid  # Traefik Infrastructure Deployment
```

### Konfiguration anpassen

```bash
# Config-Datei bearbeiten
vim /opt/SOT/production/.settings/config.yaml

# Oder mit SOT CLI
sot config edit
```

### Host-Setup durchführen

```bash
# Setup mit Ansible ausführen
sot bootstrap

# Mit spezifischen Tags
sot bootstrap --tags docker,firewall

# Dry-Run (Check-Modus)
sot bootstrap --check
```

## Troubleshooting

### Installation schlägt fehl

1. **Mit Debug-Modus wiederholen:**
   ```bash
   sudo ./bootstrap/init.sh --debug
   ```

2. **Log-Datei prüfen:**
   ```bash
   cat /tmp/sot-bootstrap-*.log
   ```

3. **Git-Fehler:**
   ```bash
   # Git manuell installieren
   apt-get update && apt-get install -y git
   ```

### Vorherige Installation existiert

```bash
# Alte Installation entfernen
sot debug delete

# Oder manuell
rm -rf /opt/SOT/production/.settings
```

### Root-Berechtigungen fehlen

```bash
# Mit sudo ausführen
sudo ./bootstrap/init.sh
```

## Architektur

### Verzeichnisstruktur

```
/opt/SOT/
├── bin/sot                          # Haupt-CLI
├── bootstrap/
│   ├── init.sh                      # Bootstrap Entry Point
│   └── dependencies.sh              # Dependency Installation
├── lib/core/bootstrap/
│   ├── init.sh                      # Bootstrap Library Loader
│   ├── args_parser.sh               # Argument Parsing
│   ├── config_defaults.sh           # Default Values
│   ├── config_writer.sh             # Config File Writer
│   ├── runner.sh                    # Task Runner & Progress Bar
│   └── tasks.sh                     # Individual Bootstrap Tasks
├── config/
│   └── default_config.yml           # Default Configuration
└── production/
    └── .settings/
        └── config.yaml              # Generated Configuration
```

### Workflow

```
curl | bash (Remote)
       │
       ├─> Git klonen → /opt/SOT
       └─> exec bootstrap/init.sh (Lokal)

bootstrap/init.sh (Lokal)
       │
       ├─> Parse --debug Flag
       ├─> Source lib/core/bootstrap/init.sh
       ├─> Parse alle Argumente
       ├─> Lade Config Defaults
       └─> run_tasks()
              │
              ├─> DEBUG_MODE=true  → run_task_verbose()
              └─> DEBUG_MODE=false → run_task() mit Progress Bar
```

## Best Practices

1. **Erste Installation:** Standard-Modus nutzen
2. **Bei Problemen:** Debug-Modus aktivieren
3. **Automatisierung:** Parameter via Argumente übergeben
4. **Testing:** Lokale Installation mit `--debug` testen
5. **Log-Dateien:** Bei Fehlern Log-Datei speichern

## Siehe auch

- [README.md](../README.md) - Hauptdokumentation
- [EXTENSIONS.md](EXTENSIONS.md) - Extension-System (AAT, TID)
- [CONFIG.md](CONFIG.md) - Konfiguration
