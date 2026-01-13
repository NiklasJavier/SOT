# SOT Docker Module

Dieses Verzeichnis enthält Docker-bezogene Skripte und Templates für das Server Operation Toolkit.

## Dateien

| Datei/Ordner | Beschreibung |
|--------------|--------------|
| `plugin.yml` | Plugin-Metadaten für SOT |
| `install.sh` | Docker-Installations-Skript für verschiedene Linux-Distributionen |
| `hooks/` | Lifecycle-Hooks (pre/post) |
| `templates/` | Docker-Compose Templates für häufig verwendete Services |

## Installation

Das Docker-Modul wird automatisch installiert, wenn `-tools "docker"` beim Setup angegeben wird:

```bash
SOT setup -tools "docker"
```

Oder manuell:

```bash
bash modules/docker/install.sh
```

## Templates

### Verfügbare Templates

| Template | Beschreibung | Port |
|----------|--------------|------|
| `grafana/` | Grafana Monitoring Dashboard | 3000 |
| `portainer/` | Docker Container Management UI | 9000 |
| `traefik/` | Reverse Proxy mit automatischem SSL | 80, 443 |

### Template-Struktur

Jedes Template enthält:

```
templates/<service>/
├── docker-compose.yml    # Docker-Compose Konfiguration
└── Dockerfile            # Optional: Custom Image Definition
```

### Template verwenden

```bash
# In Template-Verzeichnis wechseln
cd modules/docker/templates/grafana

# Container starten
docker-compose up -d

# Status prüfen
docker-compose ps

# Logs anzeigen
docker-compose logs -f
```

## Unterstützte Distributionen

Das `install.sh` Skript unterstützt:

- ✅ Ubuntu (18.04, 20.04, 22.04, 24.04)
- ✅ Debian (10, 11, 12)
- ✅ CentOS / RHEL (7, 8, 9)
- ✅ Fedora (35+)

## Konfiguration

Docker-spezifische Einstellungen können in `config.yaml` gesetzt werden:

```yaml
docker:
  enabled: "true"
  compose_version: "2.24.0"
  data_root: "/var/lib/docker"
```

## Sicherheit

- Container laufen standardmäßig als non-root User
- Netzwerke sind isoliert
- Volumes werden mit restriktiven Permissions erstellt
- Traefik-Template unterstützt automatisches Let's Encrypt SSL

## Troubleshooting

### Docker-Daemon startet nicht

```bash
sudo systemctl status docker
sudo journalctl -u docker -f
```

### Permission Denied

```bash
# Benutzer zur docker-Gruppe hinzufügen
sudo usermod -aG docker $USER
# Neu einloggen oder:
newgrp docker
```

### Container können sich nicht verbinden

```bash
# Docker-Netzwerke prüfen
docker network ls
docker network inspect bridge
```

## Siehe auch

- [Docker-Dokumentation](https://docs.docker.com/)
- [Docker-Compose Reference](https://docs.docker.com/compose/compose-file/)
