#!/usr/bin/env bash
# =============================================================================
# SOT CLI Aliases - Kurzformen für häufige Befehle
# =============================================================================
#
# Ermöglicht schnellere Eingabe durch Kurzformen:
#   SOT s     -> SOT setup
#   SOT v     -> SOT vault edit
#   SOT u     -> SOT update
#   SOT d     -> SOT doctor
#   SOT pl    -> SOT plugins list
#
# =============================================================================

[[ -n "${_SOT_CLI_ALIASES_LOADED:-}" ]] && return 0
_SOT_CLI_ALIASES_LOADED=1

# =============================================================================
# Alias-Definitionen
# =============================================================================

# Format: alias -> "target_command [default_args]"
declare -gA CLI_ALIASES=(
    # Einbuchstabige Aliasse (häufigste Befehle)
    ["s"]="setup"
    ["v"]="vault edit"
    ["u"]="update"
    ["d"]="doctor"
    ["r"]="runner"
    ["h"]="help"
    
    # Zweibuchstabige Aliasse
    ["pl"]="plugins list"
    ["pi"]="plugins info"
    ["pe"]="plugins enable"
    ["pd"]="plugins disable"
    
    ["ve"]="vault edit"
    ["vv"]="vault view"
    ["vr"]="vault rekey"
    
    ["il"]="integrations list"
    ["iv"]="integrations validate"
    
    # Dreibuchstabige Aliasse (für Klarheit)
    ["doc"]="doctor"
    ["upd"]="update"
    ["del"]="delete"
    ["run"]="runner"
    ["cfg"]="config"
    ["log"]="logs"
    
    # Quick-Actions mit @-Prefix (besondere Aktionen)
    ["@s"]="doctor --summary"
    ["@f"]="doctor --fix"
    ["@l"]="logs --tail"
    ["@c"]="config --show"
)

# =============================================================================
# Alias-Auflösung
# =============================================================================

# Löst einen Alias zu seinem Ziel-Befehl auf
# Arguments:
#   $1 - Potentieller Alias oder Befehl
# Returns:
#   0 wenn Alias gefunden, setzt RESOLVED_COMMAND
#   1 wenn kein Alias
resolve_alias() {
    local input="$1"
    RESOLVED_COMMAND=""
    RESOLVED_ARGS=()
    
    # Prüfe ob es ein Alias ist
    if [[ -n "${CLI_ALIASES[$input]:-}" ]]; then
        local target="${CLI_ALIASES[$input]}"
        
        # Target kann mehrere Wörter haben (z.B. "vault edit")
        read -ra parts <<< "$target"
        RESOLVED_COMMAND="${parts[0]}"
        RESOLVED_ARGS=("${parts[@]:1}")
        
        return 0
    fi
    
    return 1
}

# Erweitert Argumente mit aufgelöstem Alias
# Arguments:
#   $@ - Originale Argumente
# Returns:
#   Erweiterte Argumente via EXPANDED_ARGS Array
expand_alias_args() {
    local first_arg="${1:-}"
    shift || true
    
    EXPANDED_ARGS=()
    
    if resolve_alias "$first_arg"; then
        # Alias gefunden - ersetze mit Ziel + Default-Args + restliche Args
        EXPANDED_ARGS+=("$RESOLVED_COMMAND")
        EXPANDED_ARGS+=("${RESOLVED_ARGS[@]}")
        EXPANDED_ARGS+=("$@")
        return 0
    fi
    
    # Kein Alias - Original zurückgeben
    EXPANDED_ARGS=("$first_arg" "$@")
    return 1
}

# =============================================================================
# Alias-Hilfe
# =============================================================================

# Zeigt alle verfügbaren Aliasse an
show_aliases() {
    printf "\n"
    printf "  %s╔═══════════════════════════════════════════════════════════╗%s\n" "${BOLD:-}" "${NC:-}"
    printf "  %s║%s        %sSOT Shortcuts%s — Schnellere Eingabe              %s║%s\n" "${BOLD:-}" "${NC:-}" "${CYAN:-}" "${NC:-}" "${BOLD:-}" "${NC:-}"
    printf "  %s╚═══════════════════════════════════════════════════════════╝%s\n" "${BOLD:-}" "${NC:-}"
    printf "\n"
    
    printf "  ${BOLD:-}⚡ Einbuchstabige Shortcuts${NC:-}\n"
    printf "  %s\n" "$(printf '─%.0s' {1..40})"
    printf "    ${GREEN:-}%-8s${NC:-} → %s\n" "s" "setup"
    printf "    ${GREEN:-}%-8s${NC:-} → %s\n" "v" "vault edit"
    printf "    ${GREEN:-}%-8s${NC:-} → %s\n" "u" "update"
    printf "    ${GREEN:-}%-8s${NC:-} → %s\n" "d" "doctor"
    printf "    ${GREEN:-}%-8s${NC:-} → %s\n" "r" "runner"
    printf "    ${GREEN:-}%-8s${NC:-} → %s\n" "h" "help"
    
    printf "\n"
    printf "  ${BOLD:-}🔌 Plugin-Shortcuts${NC:-}\n"
    printf "  %s\n" "$(printf '─%.0s' {1..40})"
    printf "    ${GREEN:-}%-8s${NC:-} → %s\n" "pl" "plugins list"
    printf "    ${GREEN:-}%-8s${NC:-} → %s\n" "pi" "plugins info <name>"
    printf "    ${GREEN:-}%-8s${NC:-} → %s\n" "pe" "plugins enable <name>"
    printf "    ${GREEN:-}%-8s${NC:-} → %s\n" "pd" "plugins disable <name>"
    
    printf "\n"
    printf "  ${BOLD:-}🔐 Vault-Shortcuts${NC:-}\n"
    printf "  %s\n" "$(printf '─%.0s' {1..40})"
    printf "    ${GREEN:-}%-8s${NC:-} → %s\n" "ve" "vault edit"
    printf "    ${GREEN:-}%-8s${NC:-} → %s\n" "vv" "vault view"
    printf "    ${GREEN:-}%-8s${NC:-} → %s\n" "vr" "vault rekey"
    
    printf "\n"
    printf "  ${BOLD:-}⚡ Quick-Actions${NC:-}\n"
    printf "  %s\n" "$(printf '─%.0s' {1..40})"
    printf "    ${YELLOW:-}%-8s${NC:-} → %s\n" "@s" "doctor --summary (Schnell-Status)"
    printf "    ${YELLOW:-}%-8s${NC:-} → %s\n" "@f" "doctor --fix (Auto-Reparatur)"
    printf "    ${YELLOW:-}%-8s${NC:-} → %s\n" "@l" "logs --tail (Letzte Logs)"
    
    printf "\n"
    printf "  ${GREY:-}Tipp: Aliasse können mit normalen Argumenten kombiniert werden${NC:-}\n"
    printf "  ${GREY:-}      z.B.: SOT s --tags ssh,firewall${NC:-}\n"
    printf "\n"
}

# Prüft ob ein Befehl ein Alias ist und zeigt Info
is_alias() {
    local cmd="$1"
    [[ -n "${CLI_ALIASES[$cmd]:-}" ]]
}

# Gibt das Alias-Ziel zurück
get_alias_target() {
    local alias="$1"
    echo "${CLI_ALIASES[$alias]:-}"
}
