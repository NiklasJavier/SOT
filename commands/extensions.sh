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
    echo "    ${GREEN}list${NC}              Alle Extensions auflisten"
    echo "    ${GREEN}install${NC} <name>    Extension installieren (klonen + aktivieren)"
    echo "    ${GREEN}remove${NC} <name>     Extension entfernen (löschen + deaktivieren)"
    echo "    ${GREEN}sync${NC}              Alle installierten Extensions aktualisieren"
    echo "    ${GREEN}run${NC} <name> [...]  Extension-Runner ausführen"
    echo "    ${GREEN}info${NC} <name>       Details zu einer Extension anzeigen"
    echo "    ${GREEN}enable${NC} <name>     Extension aktivieren"
    echo "    ${GREEN}disable${NC} <name>    Extension deaktivieren"
    echo ""
    echo "  ${YELLOW}Schnellzugriff:${NC}"
    echo "    sot ex       = sot extensions"
    echo "    sot el       = sot ex list"
    echo "    sot ei <n>   = sot ex install <n>"
    echo "    sot er <n>   = sot ex remove <n>"
    echo "    sot es       = sot ex sync"
    echo ""
    echo "  ${YELLOW}Legacy (Rückwärtskompatibel):${NC}"
    echo "    sot aat sync      -> sot ex sync"
    echo "    sot tid sync      -> sot ex sync"
    echo "    sot integrations  -> sot ex"
    echo ""
    echo "  ${YELLOW}Beispiele:${NC}"
    echo "    sot ex install aat       # AAT installieren"
    echo "    sot ex install tid       # TID installieren"
    echo "    sot ex run aat site.yml  # AAT Runner ausführen"
    echo "    sot ex sync              # Alle aktualisieren"
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

cmd_run() {
    local name="$1"
    shift || true
    
    if [[ -z "$name" ]]; then
        err "Extension-Name erforderlich"
        echo "  Verwendung: sot ex run <name> [runner-args...]"
        echo ""
        echo "  Installierte Extensions mit Runner:"
        local ext
        while read -r ext; do
            local dir runner
            dir="$(extension_get "$ext" "dir")"
            runner="$(extension_get "$ext" "runner")"
            runner="${runner:-runner.sh}"
            if [[ -f "$dir/$runner" ]]; then
                echo "    - $ext"
            fi
        done < <(extension_list)
        exit 1
    fi
    
    # Prüfen ob Extension existiert und installiert ist
    local dir runner
    dir="$(extension_get "$name" "dir")"
    runner="$(extension_get "$name" "runner")"
    runner="${runner:-runner.sh}"
    
    if [[ -z "$dir" ]]; then
        err "Unbekannte Extension: $name"
        exit 1
    fi
    
    if [[ ! -d "$dir/.git" ]]; then
        err "Extension '$name' ist nicht installiert."
        echo "  Verwende: sot ex install $name"
        exit 1
    fi
    
    local runner_path="$dir/$runner"
    if [[ ! -f "$runner_path" ]]; then
        err "Runner nicht gefunden: $runner_path"
        exit 1
    fi
    
    # Runner ausführbar machen falls nötig
    [[ ! -x "$runner_path" ]] && chmod +x "$runner_path"
    
    echo ""
    echo "  ${BOLD}Extension Runner: ${YELLOW}$name${NC}"
    echo "  ${GREY}Pfad: $runner_path${NC}"
    echo ""
    
    # Environment exportieren
    export SOT_ROOT="${SOT_ROOT:-}"
    export SOT_CONFIG_FILE="${CONFIG_FILE:-}"
    export EXTENSION_NAME="$name"
    export EXTENSION_DIR="$dir"
    
    # Runner ausführen
    exec bash "$runner_path" "$@"
}

cmd_enable() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        err "Extension-Name erforderlich"
        exit 1
    fi
    
    _update_config_value "${name}_enabled" "true"
    echo "  ${GREEN}✓${NC} Extension '$name' aktiviert."
}

cmd_disable() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        err "Extension-Name erforderlich"
        exit 1
    fi
    
    _update_config_value "${name}_enabled" "false"
    echo "  ${GREEN}✓${NC} Extension '$name' deaktiviert."
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
        run|exec|r)
            cmd_run "$@"
            ;;
        info|show)
            cmd_info "$@"
            ;;
        enable|on)
            cmd_enable "$@"
            ;;
        disable|off)
            cmd_disable "$@"
            ;;
        help|--help|-h|"")
            show_usage
            ;;
        *)
            # Prüfe ob es ein Extension-Name ist (Legacy-Kompatibilität)
            # z.B. "sot ex aat" -> zeigt info zu aat
            local repo_url
            repo_url="$(extension_get "$command" "repo_url" 2>/dev/null || true)"
            if [[ -n "$repo_url" ]]; then
                cmd_info "$command"
            else
                err "Unbekannter Command: $command"
                show_usage
                exit 1
            fi
            ;;
    esac
}

main "$@"
