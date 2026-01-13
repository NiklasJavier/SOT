#!/usr/bin/env bash
# =============================================================================
# @cmd: update
# @aliases: u, upd
# @category: maintenance
# @description: SOT und alle Extensions auf die neueste Version aktualisieren
# @usage: sot update [--force] [--sot-only] [--extensions-only]
# @example: sot update
# @example: sot update --force
# @example: sot u
# =============================================================================
## Aktualisiert SOT und alle installierten Extensions.
## - SOT Repository: git fetch + reset --hard (überschreibt lokale Änderungen)
## - Extensions: git fetch + reset --hard für alle installierten
##
## Optionen:
##   --force              Keine Bestätigung vor Überschreiben
##   --sot-only           Nur SOT aktualisieren, keine Extensions
##   --extensions-only    Nur Extensions aktualisieren, nicht SOT
##   --dry-run            Zeigt was aktualisiert würde, ohne Änderungen
# =============================================================================

set -euo pipefail

# =============================================================================
# Initialisierung
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Library laden
if [[ -f "$SOT_ROOT/lib/init.sh" ]]; then
    source "$SOT_ROOT/lib/init.sh"
else
    echo "FEHLER: SOT Library nicht gefunden: $SOT_ROOT/lib/init.sh" >&2
    exit 1
fi

# Extensions Manager laden
if [[ -f "$SOT_ROOT/lib/extensions/manager.sh" ]]; then
    source "$SOT_ROOT/lib/extensions/manager.sh"
fi

# =============================================================================
# Konfiguration
# =============================================================================

FORCE=false
SOT_ONLY=false
EXTENSIONS_ONLY=false
DRY_RUN=false

# Parse Argumente
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f)
            FORCE=true
            shift
            ;;
        --sot-only|--sot)
            SOT_ONLY=true
            shift
            ;;
        --extensions-only|--ext)
            EXTENSIONS_ONLY=true
            shift
            ;;
        --dry-run|-n)
            DRY_RUN=true
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
    echo "  ${BOLD}SOT Update${NC} - Aktualisiert SOT und Extensions"
    echo ""
    echo "  ${YELLOW}Verwendung:${NC}"
    echo "    sot update [optionen]"
    echo ""
    echo "  ${YELLOW}Optionen:${NC}"
    echo "    ${GREEN}--force, -f${NC}          Keine Bestätigung vor Überschreiben"
    echo "    ${GREEN}--sot-only${NC}           Nur SOT aktualisieren"
    echo "    ${GREEN}--extensions-only${NC}    Nur Extensions aktualisieren"
    echo "    ${GREEN}--dry-run, -n${NC}        Zeigt was aktualisiert würde"
    echo ""
    echo "  ${YELLOW}Aliasse:${NC}"
    echo "    sot u, sot upd"
    echo ""
}

# Aktualisiert ein Git-Repository
# Arguments: $1 - Verzeichnis, $2 - Branch (optional)
update_repo() {
    local dir="$1"
    local branch="${2:-}"
    local name
    name="$(basename "$dir")"
    
    if [[ ! -d "$dir/.git" ]]; then
        echo "    ${GREY}Nicht installiert: $dir${NC}"
        return 1
    fi
    
    cd "$dir" || return 1
    
    # Aktuellen Branch ermitteln falls nicht angegeben
    if [[ -z "$branch" ]]; then
        branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
    fi
    
    # Remote und lokalen Hash holen
    local local_hash remote_hash
    local_hash="$(git rev-parse HEAD 2>/dev/null || echo "unknown")"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "    ${YELLOW}[DRY-RUN]${NC} Würde aktualisieren: $name ($branch)"
        return 0
    fi
    
    echo "    ${GREY}├──${NC} Aktualisiere ${YELLOW}$name${NC} (branch: $branch)..."
    
    # Fetch
    if ! sudo git fetch origin "$branch" --quiet 2>/dev/null; then
        echo "    ${RED}✗${NC} Fetch fehlgeschlagen"
        return 1
    fi
    
    remote_hash="$(git rev-parse "origin/$branch" 2>/dev/null || echo "unknown")"
    
    # Prüfen ob Update nötig
    if [[ "$local_hash" == "$remote_hash" ]]; then
        echo "    ${GREEN}✓${NC} $name ist aktuell"
        return 0
    fi
    
    # Hard reset (überschreibt lokale Änderungen)
    if sudo git reset --hard "origin/$branch" --quiet 2>/dev/null; then
        sudo git clean -fd --quiet 2>/dev/null || true
        
        local new_hash
        new_hash="$(git rev-parse --short HEAD 2>/dev/null)"
        echo "    ${GREEN}✓${NC} $name aktualisiert (${local_hash:0:7} → $new_hash)"
        return 0
    else
        echo "    ${RED}✗${NC} Reset fehlgeschlagen"
        return 1
    fi
}

# =============================================================================
# Update-Funktionen
# =============================================================================

update_sot() {
    echo ""
    echo "  ${BOLD}┌── SOT Core${NC}"
    
    local sot_branch="${branch:-production}"
    
    if update_repo "$SOT_ROOT" "$sot_branch"; then
        echo "  ${BOLD}└── ${GREEN}✓${NC} SOT aktualisiert${NC}"
    else
        echo "  ${BOLD}└── ${RED}✗${NC} SOT Update fehlgeschlagen${NC}"
        return 1
    fi
}

update_extensions() {
    echo ""
    echo "  ${BOLD}┌── Extensions${NC}"
    
    local ext_count=0
    local ext_updated=0
    local ext_failed=0
    
    # Alle Extensions durchgehen (nicht nur aktivierte)
    local ext
    while read -r ext; do
        local dir
        dir="$(extension_get "$ext" "dir")"
        local ext_branch
        ext_branch="$(extension_get "$ext" "branch")"
        
        # Nur installierte Extensions aktualisieren
        if [[ -d "$dir/.git" ]]; then
            ((++ext_count))
            if update_repo "$dir" "$ext_branch"; then
                ((++ext_updated))
            else
                ((++ext_failed))
            fi
        fi
    done < <(extension_list 2>/dev/null || true)
    
    if [[ "$ext_count" -eq 0 ]]; then
        echo "    ${GREY}Keine Extensions installiert${NC}"
        echo "    ${GREY}→ sot ex list${NC}"
    fi
    
    echo "  ${BOLD}└── ${GREEN}$ext_updated${NC}/${ext_count} Extensions aktualisiert${NC}"
    
    [[ "$ext_failed" -gt 0 ]] && return 1
    return 0
}

# =============================================================================
# Hauptprogramm
# =============================================================================

main() {
    echo ""
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo -e "  ║              ${GREEN}SOT Update${NC} - System aktualisieren              ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    
    local start_time
    start_time=$(date +%s)
    
    local sot_result=0
    local ext_result=0
    
    # SOT aktualisieren
    if [[ "$EXTENSIONS_ONLY" != "true" ]]; then
        update_sot || sot_result=$?
    fi
    
    # Extensions aktualisieren
    if [[ "$SOT_ONLY" != "true" ]]; then
        update_extensions || ext_result=$?
    fi
    
    # Zusammenfassung
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo ""
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    if [[ "$sot_result" -eq 0 && "$ext_result" -eq 0 ]]; then
        echo -e "  ║  ${GREEN}✓ Update abgeschlossen${NC}                                      ║"
    else
        echo -e "  ║  ${YELLOW}! Update mit Warnungen abgeschlossen${NC}                        ║"
    fi
    echo "  ║  Dauer: ${duration} Sekunde(n)                                        ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    return $((sot_result + ext_result))
}

main "$@"
