# SOT Maintenance

Dieses Verzeichnis enthält Wartungsskripte für das Server Operation Toolkit.

## Verfügbare Skripte

| Skript | Beschreibung | SOT-Befehl |
|--------|--------------|------------|
| `update.sh` | SOT-Repository aktualisieren | `SOT maintenance update` |
| `delete.sh` | SOT-Installation entfernen | `SOT maintenance delete` |
| `cleanup_old_users.sh` | Alte Test-Benutzer bereinigen | `SOT maintenance cleanup_old_users` |

## update.sh

Aktualisiert das lokale SOT-Repository auf den neuesten Stand.

```bash
SOT maintenance update
```

**Aktionen:**
1. `git fetch` — Remote-Änderungen holen
2. `git pull --rebase --autostash` — Änderungen anwenden

**Timeout:** 60s für fetch, 120s für pull

## delete.sh

Entfernt die SOT-Installation vollständig.

```bash
SOT maintenance delete
```

**Erstellt Backup:**
- Vault-Zugangsdaten in `$opt_data_dir/devopsVaultAccessSecret-*.yml`
- Ausführbares Skript `openVault.sh` für späteren Vault-Zugriff

**Löscht:**
- Repository (`/etc/DevOpsToolkit`)
- Symlink (`/usr/sbin/SOT`)
- Log-Datei

## cleanup_old_users.sh

Bereinigt alte Test-Benutzer und UFW-Regeln.

```bash
SOT maintenance cleanup_old_users
```

⚠️ **Warnung:** Erfordert interaktive Bestätigung!

**Aktionen:**
1. Findet Benutzer mit 11-Zeichen-Namen in `/home`
2. Löscht diese Benutzer (außer aktuellen)
3. Entfernt zugehörige `/opt/SRV-*` Verzeichnisse
4. Bereinigt UFW-Regeln (behält nur SSH-Port)

## Entwicklung

Alle Skripte nutzen die gemeinsame Bibliothek:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_ROOT/lib/init.sh"
```
