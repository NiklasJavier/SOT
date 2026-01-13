#!/usr/bin/env bash
# =============================================================================
# @cmd: extensions
# @aliases: ex
# @category: system
# @description: Extensions verwalten (AAT, TID, etc.)
# @usage: sot ex [list|install|remove|sync|info <name>]
# @example: sot ex list
# @example: sot ex install aat
# @example: sot ex remove tid
# @example: sot ex sync
# @example: sot ex info aat
# =============================================================================

set -euo pipefail

# Load SOT library
if [[ -z "${SOT_ROOT:-}" ]]; then
    SOT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$SOT_ROOT/lib/init.sh"

# =============================================================================
# Usage
# =============================================================================

show_usage() {
    echo ""
    echo "  ${BOLD}SOT Extensions${NC} - Externe Integrationen verwalten"
    echo ""
    echo "  ${YELLOW}Verwendung:${NC}"
    echo "    sot ex <command> [options]"
    echo ""
    echo "  ${YELLOW}Commands:${NC}"
    echo "    ${GREEN}list${NC}            Alle konfigurierten Extensions auflisten"
    echo "    ${GREEN}install${NC} <name>  Extension installieren (klonen)"
    echo "    ${GREEN}remove${NC} <name>   Extension entfernen (Verzeichnis löschen)"
    echo "    ${GREEN}sync${NC}            Alle aktivierten Extensions aktualisieren"
    echo "    ${GREEN}info${NC} <name>     Details zu einer Extension anzeigen"
    echo "    ${GREEN}enable${NC} <name>   Extension aktivieren (in Config)"
    echo "    ${GREEN}disable${NC} <name>  Extension deaktivieren (in Config)"
    echo ""
    echo "  ${YELLOW}Aliasse:${NC}"
    echo "    sot ex       = sot extensions"
    echo "    sot el       = sot ex list"
    echo "    sot ei <n>   = sot ex install <n>"
    echo "    sot er <n>   = sot ex remove <n>"
    echo "    sot es       = sot ex sync"
    echo ""
    echo "  ${YELLOW}Beispiele:${NC}"
    echo "    sot ex install aat     # AAT Extension installieren"
    echo "    sot ex install tid     # TID Extension installieren"
    echo "    sot ex remove aat      # AAT Extension entfernen"
    echo "    sot ex sync            # Alle aktivierten aktualisieren"
    echo ""
    echo "  ${YELLOW}Konfigurierte Extensions:${NC}"
    
    local ext
    while read -r ext; do
        local enabled desc
        enabled="$(extension_is_enabled "$ext" && echo "${GREEN}✓${NC}" || echo "${GREY}○${NC}")"
        desc="$(extension_get "$ext" "description")"
        echo "    $enabled ${YELLOW}$ext${NC} - ${desc:-Keine Beschreibung}"
    done < <(extension_list)
    
    echo ""
}

# =============================================================================
# Commands
# =============================================================================

cmd_list() {
    echo ""
    echo "  ${BOLD}Verfügbare Extensions:${NC}"
    echo ""
    
    local ext
    while read -r ext; do
        local status_icon dir desc enabled installed
        desc="$(extension_get "$ext" "description")"
        dir="$(extension_get "$ext" "dir")"
        enabled="$(extension_is_enabled "$ext" && echo "true" || echo "false")"
        installed="$([[ -d "$dir/.git" ]] && echo "true" || echo "false")"
        
        # Status bestimmen
        if [[ "$installed" == "true" ]]; then
            if [[ "$enabled" == "true" ]]; then
                status_icon="${GREEN}✓${NC} Installiert & Aktiviert"
            else
                status_icon="${YELLOW}○${NC} Installiert (deaktiviert)"
            fi
        else
            status_icon="${GREY}○${NC} Nicht installiert"
        fi
        
        echo "    ${BOLD}${ext^^}${NC}"
        echo "      Status:       $status_icon"
        echo "      Beschreibung: ${desc:-n/a}"
        echo "      Verzeichnis:  ${dir:-n/a}"
        if [[ "$installed" != "true" ]]; then
            echo "      ${GREY}→ sot ex install $ext${NC}"
        fi
        echo ""
    done < <(extension_list)
    
    echo "  ${GREY}Tipp: 'sot ex install <name>' zum Installieren${NC}"
    echo ""
}

cmd_sync() {
    echo ""
    echo "  ${BOLD}Extensions synchronisieren...${NC}"
    
    extension_sync_all
    
    echo "  ${GREEN}✓${NC} Synchronisation abgeschlossen"
    echo ""
}

cmd_install() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        err "Extension-Name erforderlich"
        echo "  Verwendung: sot ex install <name>"
        echo ""
        echo "  Verfügbare Extensions:"
        extension_list | while read -r ext; do
            echo "    - $ext"
        done
        exit 1
    fi
    
    local dir repo_url branch
    dir="$(extension_get "$name" "dir")"
    repo_url="$(extension_get "$name" "repo_url")"
    branch="$(extension_get "$name" "branch")"
    
    if [[ -z "$repo_url" ]]; then
        err "Unbekannte Extension: $name"
        echo "  Verfügbare Extensions:"
        extension_list | while read -r ext; do
            echo "    - $ext"
        done
        exit 1
    fi
    
    echo ""
    echo "  ${BOLD}Extension installieren: ${YELLOW}$name${NC}"
    echo ""
    
    if [[ -d "$dir/.git" ]]; then
        echo "  ${YELLOW}!${NC} Extension bereits installiert in: $dir"
        echo "  ${GREY}Verwende 'sot ex sync' zum Aktualisieren${NC}"
        echo ""
        return 0
    fi
    
    # Extension installieren
    extension_sync "$name"
    
    # Extension in Config aktivieren
    echo ""
    echo "  ${GREY}Aktiviere Extension in Konfiguration...${NC}"
    _update_config_value "${name}_enabled" "true"
    
    echo ""
    echo "  ${GREEN}✓${NC} Extension '$name' erfolgreich installiert und aktiviert!"
    echo ""
    echo "  ${YELLOW}Nächste Schritte:${NC}"
    echo "    - Konfiguration anpassen: ${GREY}sot ex info $name${NC}"
    echo "    - Extension ausführen:    ${GREY}sot runner $name${NC}"
    echo ""
}

cmd_remove() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        err "Extension-Name erforderlich"
        echo "  Verwendung: sot ex remove <name>"
        exit 1
    fi
    
    local dir
    dir="$(extension_get "$name" "dir")"
    
    if [[ -z "$dir" ]]; then
        err "Unbekannte Extension: $name"
        exit 1
    fi
    
    echo ""
    echo "  ${BOLD}Extension entfernen: ${YELLOW}$name${NC}"
    echo ""
    
    if [[ ! -d "$dir" ]]; then
        echo "  ${GREY}Extension nicht installiert: $dir${NC}"
        echo ""
        return 0
    fi
    
    echo "  ${YELLOW}Warnung:${NC} Verzeichnis wird gelöscht: $dir"
    read -p "  Fortfahren? [y/N] " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "  ${GREY}Abgebrochen.${NC}"
        return 0
    fi
    
    echo "  ${GREY}Entferne Verzeichnis...${NC}"
    sudo rm -rf "$dir"
    
    # Extension in Config deaktivieren
    _update_config_value "${name}_enabled" "false"
    
    echo "  ${GREEN}✓${NC} Extension '$name' entfernt und deaktiviert."
    echo ""
}

# Hilfsfunktion zum Aktualisieren der Config
_update_config_value() {
    local key="$1"
    local value="$2"
    
    if [[ -n "${CONFIG_FILE:-}" && -f "$CONFIG_FILE" ]]; then
        if grep -q "^${key}:" "$CONFIG_FILE" 2>/dev/null; then
            sudo sed -i "s|^${key}:.*|${key}: \"${value}\"|" "$CONFIG_FILE"
        fi
    fi
}

cmd_info() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        err "Extension-Name erforderlich"
        echo "  Verwendung: sot extensions info <name>"
        exit 1
    fi
    
    echo ""
    extension_info "$name"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    local command="${1:-}"
    shift || true
    
    case "$command" in
        list|ls|l)
            cmd_list
            ;;
        install|add|i)
            cmd_install "$@"
            ;;
        remove|rm|uninstall|delete|del)
            cmd_remove "$@"
            ;;
        sync|update|up)
            cmd_sync
            ;;
        info|show)
            cmd_info "$@"
            ;;
        help|--help|-h|"")
            show_usage
            ;;
        *)
            err "Unbekannter Command: $command"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
