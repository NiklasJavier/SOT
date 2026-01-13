#!/usr/bin/env bash
# =============================================================================
# @cmd: delete
# @aliases: del, uninstall, remove
# @category: maintenance
# @description: SOT-Installation vollständig entfernen
# @usage: sot delete [--force] [--keep-extensions] [--keep-config] [--no-backup]
# @example: sot delete
# @example: sot delete --force
# @example: sot del --keep-config
# =============================================================================
## Entfernt die SOT-Installation vollständig vom System.
## 
## Was wird gelöscht:
##   - SOT Repository (/opt/SOT)
##   - Alle installierten Extensions (AAT, TID, etc.)
##   - CLI Symlinks (/usr/sbin/SOT, /usr/sbin/sot)
##   - Lib/Bin Symlinks (/usr/local/lib/sot, /usr/local/bin/sot-bin)
##   - Konfigurationsverzeichnisse
##   - Log-Dateien
##
## Optionen:
##   --force            Keine Bestätigung vor Löschung
##   --keep-extensions  Extensions nicht löschen
##   --keep-config      Konfiguration behalten
##   --no-backup        Kein Vault-Backup erstellen
# =============================================================================

set -euo pipefail

# =============================================================================
# Initialisierung
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Library laden (falls noch verfügbar)
if [[ -f "$SOT_ROOT/lib/init.sh" ]]; then
    source "$SOT_ROOT/lib/init.sh"
else
    # Fallback Farben
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    BOLD='\033[1m'
    GREY='\033[1;90m'
    NC='\033[0m'
fi

# Extensions Manager laden
if [[ -f "$SOT_ROOT/lib/extensions/manager.sh" ]]; then
    source "$SOT_ROOT/lib/extensions/manager.sh"
fi

# =============================================================================
# Konfiguration
# =============================================================================

FORCE=false
KEEP_EXTENSIONS=false
KEEP_CONFIG=false
NO_BACKUP=false

# Bekannte Pfade
CLONE_DIR="${clone_dir:-/opt/SOT}"
SYSTEMLINK_PATH="${systemlink_path:-/usr/sbin/SOT}"
SYSTEMLINK_PATH_LOWER="/usr/sbin/sot"
LIB_SYMLINK="/usr/local/lib/sot"
BIN_SYMLINK="/usr/local/bin/sot-bin"
LOG_FILE="${log_file:-/var/log/devops_commands.log}"
OPT_DATA_DIR="${opt_data_dir:-/opt/SOT/.sot-data}"
CONFIG_DIR="${SETTINGS_DIR:-}"

# Parse Argumente
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f)
            FORCE=true
            shift
            ;;
        --keep-extensions|--keep-ext)
            KEEP_EXTENSIONS=true
            shift
            ;;
        --keep-config|--keep-cfg)
            KEEP_CONFIG=true
            shift
            ;;
        --no-backup)
            NO_BACKUP=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# =============================================================================
# Hilfsfunktionen
# =============================================================================

show_help() {
    echo ""
    echo "  ${BOLD}SOT Delete${NC} - Installation vollständig entfernen"
    echo ""
    echo "  ${YELLOW}Verwendung:${NC}"
    echo "    sot delete [optionen]"
    echo ""
    echo "  ${YELLOW}Optionen:${NC}"
    echo "    ${GREEN}--force, -f${NC}          Keine Bestätigung"
    echo "    ${GREEN}--keep-extensions${NC}    Extensions behalten"
    echo "    ${GREEN}--keep-config${NC}        Konfiguration behalten"
    echo "    ${GREEN}--no-backup${NC}          Kein Vault-Backup"
    echo ""
    echo "  ${YELLOW}Aliasse:${NC}"
    echo "    sot del, sot uninstall, sot remove"
    echo ""
}

# Sicheres Löschen mit Logging
safe_delete() {
    local path="$1"
    local type="$2"  # file, dir, symlink
    local desc="$3"
    
    case "$type" in
        symlink)
            if [[ -L "$path" ]]; then
                sudo rm -f "$path"
                echo "    ${GREEN}✓${NC} $desc entfernt: $path"
                return 0
            fi
            ;;
        file)
            if [[ -f "$path" ]]; then
                sudo rm -f "$path"
                echo "    ${GREEN}✓${NC} $desc entfernt: $path"
                return 0
            fi
            ;;
        dir)
            if [[ -d "$path" ]]; then
                sudo rm -rf "$path"
                echo "    ${GREEN}✓${NC} $desc entfernt: $path"
                return 0
            fi
            ;;
    esac
    
    echo "    ${GREY}○${NC} $desc nicht vorhanden: $path"
    return 0
}

# =============================================================================
# Backup-Funktionen
# =============================================================================

create_vault_backup() {
    local backup_dir="/tmp/sot-backup-$(date +%Y%m%d-%H%M%S)"
    local vault_file="${vault_file:-}"
    local vault_secret="${vault_secret:-}"
    
    echo ""
    echo "  ${BOLD}┌── Vault Backup${NC}"
    
    if [[ -z "$vault_file" || ! -f "$vault_file" ]]; then
        echo "    ${GREY}Keine Vault-Datei gefunden${NC}"
        echo "  ${BOLD}└── ${GREY}Übersprungen${NC}"
        return 0
    fi
    
    mkdir -p "$backup_dir"
    
    # Vault-Datei kopieren
    cp "$vault_file" "$backup_dir/"
    
    # Backup-Info erstellen
    cat > "$backup_dir/BACKUP_INFO.txt" << EOF
SOT Vault Backup
================
Erstellt: $(date)
Vault-Datei: $vault_file
Vault-Secret: $vault_secret

WICHTIG: Diese Datei enthält sensible Daten!
Bitte sicher aufbewahren und nach Verwendung löschen.

Zum Entschlüsseln:
  ansible-vault view vault.yml --vault-password-file=<secret-file>
EOF
    
    chmod 600 "$backup_dir"/*
    
    echo "    ${GREEN}✓${NC} Backup erstellt: $backup_dir"
    echo "  ${BOLD}└── ${YELLOW}WICHTIG: Backup sichern!${NC}"
    echo ""
    echo "    ${GREY}Backup-Verzeichnis: ${YELLOW}$backup_dir${NC}"
    echo ""
}

# =============================================================================
# Lösch-Funktionen
# =============================================================================

delete_extensions() {
    echo ""
    echo "  ${BOLD}┌── Extensions${NC}"
    
    local ext_count=0
    
    # Alle Extensions durchgehen
    if declare -F extension_list &>/dev/null; then
        local ext
        while read -r ext; do
            local dir
            dir="$(extension_get "$ext" "dir" 2>/dev/null || true)"
            
            if [[ -n "$dir" && -d "$dir" ]]; then
                ((++ext_count))
                safe_delete "$dir" "dir" "Extension ${ext^^}"
            fi
        done < <(extension_list 2>/dev/null || true)
    fi
    
    # Bekannte Extension-Pfade prüfen
    for ext_dir in /opt/AAT /opt/TID; do
        if [[ -d "$ext_dir" ]]; then
            ((++ext_count))
            safe_delete "$ext_dir" "dir" "Extension $(basename "$ext_dir")"
        fi
    done
    
    if [[ "$ext_count" -eq 0 ]]; then
        echo "    ${GREY}Keine Extensions installiert${NC}"
    fi
    
    echo "  ${BOLD}└── Fertig${NC}"
}

delete_symlinks() {
    echo ""
    echo "  ${BOLD}┌── Symlinks${NC}"
    
    safe_delete "$SYSTEMLINK_PATH" "symlink" "CLI Symlink (SOT)"
    safe_delete "$SYSTEMLINK_PATH_LOWER" "symlink" "CLI Symlink (sot)"
    safe_delete "$LIB_SYMLINK" "symlink" "Lib Symlink"
    safe_delete "$BIN_SYMLINK" "symlink" "Bin Symlink"
    
    echo "  ${BOLD}└── Fertig${NC}"
}

delete_sot_core() {
    echo ""
    echo "  ${BOLD}┌── SOT Core${NC}"
    
    safe_delete "$CLONE_DIR" "dir" "SOT Repository"
    safe_delete "$LOG_FILE" "file" "Log-Datei"
    
    # Weitere mögliche SOT-Verzeichnisse
    safe_delete "/etc/DevOpsToolkit" "dir" "Legacy Verzeichnis"
    
    echo "  ${BOLD}└── Fertig${NC}"
}

delete_config() {
    echo ""
    echo "  ${BOLD}┌── Konfiguration${NC}"
    
    # Settings-Verzeichnisse
    if [[ -n "$CONFIG_DIR" && -d "$CONFIG_DIR" ]]; then
        safe_delete "$CONFIG_DIR" "dir" "Settings"
    fi
    
    # Data-Verzeichnis
    safe_delete "$OPT_DATA_DIR" "dir" "Data-Verzeichnis"
    
    echo "  ${BOLD}└── Fertig${NC}"
}

# =============================================================================
# Bestätigung
# =============================================================================

confirm_deletion() {
    echo ""
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo -e "  ║           ${RED}⚠ SOT DEINSTALLATION${NC}                              ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  ${YELLOW}Folgende Komponenten werden gelöscht:${NC}"
    echo ""
    echo "    ${GREY}•${NC} SOT Repository: ${YELLOW}$CLONE_DIR${NC}"
    
    if [[ "$KEEP_EXTENSIONS" != "true" ]]; then
        echo "    ${GREY}•${NC} Alle installierten Extensions (AAT, TID, ...)"
    fi
    
    echo "    ${GREY}•${NC} CLI Symlinks: ${YELLOW}$SYSTEMLINK_PATH${NC}"
    echo "    ${GREY}•${NC} Lib/Bin Symlinks"
    
    if [[ "$KEEP_CONFIG" != "true" ]]; then
        echo "    ${GREY}•${NC} Konfigurationsverzeichnisse"
    fi
    
    echo "    ${GREY}•${NC} Log-Dateien"
    echo ""
    
    if [[ "$NO_BACKUP" != "true" ]]; then
        echo "    ${GREEN}✓${NC} Vault-Backup wird erstellt"
    else
        echo "    ${RED}✗${NC} Kein Vault-Backup (--no-backup)"
    fi
    
    echo ""
    
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    
    echo -e "  ${RED}Diese Aktion kann nicht rückgängig gemacht werden!${NC}"
    echo ""
    read -p "  Fortfahren? Tippe 'DELETE' zum Bestätigen: " confirm
    
    if [[ "$confirm" != "DELETE" ]]; then
        echo ""
        echo "  ${GREY}Abgebrochen.${NC}"
        echo ""
        exit 0
    fi
}

# =============================================================================
# Hauptprogramm
# =============================================================================

main() {
    # Bestätigung holen
    confirm_deletion
    
    local start_time
    start_time=$(date +%s)
    
    echo ""
    echo "  ${BOLD}Deinstallation gestartet...${NC}"
    
    # Vault-Backup erstellen
    if [[ "$NO_BACKUP" != "true" ]]; then
        create_vault_backup
    fi
    
    # Extensions löschen
    if [[ "$KEEP_EXTENSIONS" != "true" ]]; then
        delete_extensions
    fi
    
    # Symlinks entfernen
    delete_symlinks
    
    # Konfiguration löschen
    if [[ "$KEEP_CONFIG" != "true" ]]; then
        delete_config
    fi
    
    # SOT Core löschen (am Ende, da wir das Script von dort ausführen)
    delete_sot_core
    
    # Zusammenfassung
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo ""
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo -e "  ║  ${GREEN}✓ SOT wurde erfolgreich deinstalliert${NC}                       ║"
    echo "  ║  Dauer: ${duration} Sekunde(n)                                        ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    if [[ "$NO_BACKUP" != "true" ]]; then
        echo "  ${YELLOW}Hinweis:${NC} Vault-Backup liegt in /tmp/sot-backup-*"
        echo "  ${GREY}Bitte sichern und anschließend löschen!${NC}"
        echo ""
    fi
    
    echo "  ${GREY}Zum Neuinstallieren:${NC}"
    echo "    curl -fsSL \"https://raw.githubusercontent.com/NiklasJavier/SOT/production/bootstrap/init.sh\" | bash"
    echo ""
}

main "$@"
