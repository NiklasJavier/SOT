#!/usr/bin/env bash
# =============================================================================
# @cmd: extensions
# @category: system
# @description: Extensions verwalten (AAT, TID, etc.)
# @usage: sot extensions [list|sync|info <name>]
# @example: sot extensions list
# @example: sot extensions sync
# @example: sot extensions info aat
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
    echo "    sot extensions <command> [options]"
    echo ""
    echo "  ${YELLOW}Commands:${NC}"
    echo "    ${GREEN}list${NC}         Alle konfigurierten Extensions auflisten"
    echo "    ${GREEN}sync${NC}         Alle aktivierten Extensions synchronisieren"
    echo "    ${GREEN}info${NC} <name>  Details zu einer Extension anzeigen"
    echo "    ${GREEN}enable${NC} <name>   Extension aktivieren (in Config)"
    echo "    ${GREEN}disable${NC} <name>  Extension deaktivieren (in Config)"
    echo ""
    echo "  ${YELLOW}Beispiele:${NC}"
    echo "    sot extensions list"
    echo "    sot extensions sync"
    echo "    sot extensions info aat"
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
    echo "  ${BOLD}Konfigurierte Extensions:${NC}"
    echo ""
    
    local ext
    while read -r ext; do
        local enabled status_icon dir desc
        enabled="$(extension_is_enabled "$ext")"
        desc="$(extension_get "$ext" "description")"
        dir="$(extension_get "$ext" "dir")"
        
        if [[ "$enabled" == "true" ]]; then
            if [[ -d "$dir/.git" ]]; then
                status_icon="${GREEN}✓${NC} Installiert"
            else
                status_icon="${YELLOW}○${NC} Nicht installiert"
            fi
        else
            status_icon="${GREY}○${NC} Deaktiviert"
        fi
        
        echo "    ${BOLD}${ext^^}${NC}"
        echo "      Status:       $status_icon"
        echo "      Beschreibung: ${desc:-n/a}"
        echo "      Verzeichnis:  ${dir:-n/a}"
        echo ""
    done < <(extension_list)
}

cmd_sync() {
    echo ""
    echo "  ${BOLD}Extensions synchronisieren...${NC}"
    
    extension_sync_all
    
    echo "  ${GREEN}✓${NC} Synchronisation abgeschlossen"
    echo ""
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
        list|ls)
            cmd_list
            ;;
        sync|update)
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
