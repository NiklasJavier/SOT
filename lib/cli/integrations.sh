#!/usr/bin/env bash
# =============================================================================
# SOT Integration Framework
# =============================================================================
#
# Dynamisches System für externe Repository-Integrationen.
# Ermöglicht einfaches Hinzufügen neuer Integrationen ohne Code-Änderungen.
#
# Jede Integration benötigt in der Config:
#   <name>_enabled: "true"
#   <name>_repo_url: "https://github.com/..."
#   <name>_dir: "/opt/<NAME>"
#   <name>_branch: "main"
#   <name>_type: "ansible|terraform|custom"
#
# Optional:
#   <name>_runner: "runner.sh"       # Entry-Point Skript
#   <name>_inventory_path: "..."     # Für Ansible
#   <name>_inventory_vars: "..."     # Vars für Inventory
#
# =============================================================================

[[ -n "${_SOT_INTEGRATIONS_LOADED:-}" ]] && return 0
_SOT_INTEGRATIONS_LOADED=1

# =============================================================================
# Globale Variablen
# =============================================================================

# Registrierte Integrationen (dynamisch gefüllt)
declare -A INTEGRATIONS=()
declare -A INTEGRATION_TYPES=()
declare -A INTEGRATION_DIRS=()
declare -A INTEGRATION_REPOS=()
declare -A INTEGRATION_BRANCHES=()
declare -A INTEGRATION_RUNNERS=()
declare -A INTEGRATION_DESCRIPTIONS=()

# Standard-Integrationstypen
declare -A INTEGRATION_TYPE_INFO=(
    ["ansible"]="🎭|Ansible Automation"
    ["terraform"]="🏗️ |Terraform Infrastructure"
    ["custom"]="🔧|Custom Integration"
    ["script"]="📜|Script Collection"
)

# =============================================================================
# Integration Discovery
# =============================================================================

# Entdeckt alle Integrationen aus der Konfiguration
# Sucht nach Variablen mit dem Muster: <name>_enabled
discover_integrations() {
    local var_name var_value
    local -a found_integrations=()
    
    # Alle *_enabled Variablen finden via declare
    local all_vars
    all_vars=$(declare -p 2>/dev/null | grep -oE '[a-z]+_enabled' | sort -u)
    
    for var_name in $all_vars; do
        if [[ "$var_name" =~ ^([a-z]+)_enabled$ ]]; then
            local name="${BASH_REMATCH[1]}"
            var_value="${!var_name:-}"
            
            # Bekannte Nicht-Integrations-Variablen überspringen
            [[ "$name" == "runner" || "$name" == "vault" || "$name" == "ansible" || "$name" == "ssh" ]] && continue
            
            # Nur wenn repo_url existiert ist es eine Integration
            local repo_var="${name}_repo_url"
            [[ -z "${!repo_var:-}" ]] && continue
            
            if is_true "$var_value"; then
                found_integrations+=("$name")
            fi
        fi
    done
    
    # Gefundene Integrationen registrieren
    for name in "${found_integrations[@]}"; do
        register_integration "$name"
    done
    
    return 0
}

# Registriert eine einzelne Integration
register_integration() {
    local name="$1"
    local name_upper="${name^^}"
    
    # Variablen-Namen
    local enabled_var="${name}_enabled"
    local repo_var="${name}_repo_url"
    local dir_var="${name}_dir"
    local branch_var="${name}_branch"
    local type_var="${name}_type"
    local runner_var="${name}_runner"
    local desc_var="${name}_description"
    
    # Werte auslesen mit Defaults
    local enabled="${!enabled_var:-false}"
    local repo_url="${!repo_var:-}"
    local dir="${!dir_var:-/opt/$name_upper}"
    local branch="${!branch_var:-main}"
    local type="${!type_var:-custom}"
    local runner="${!runner_var:-runner.sh}"
    local description="${!desc_var:-$name_upper Integration}"
    
    # Nur registrieren wenn aktiviert
    if ! is_true "$enabled"; then
        return 0
    fi
    
    # In Arrays speichern
    INTEGRATIONS["$name"]="$enabled"
    INTEGRATION_TYPES["$name"]="$type"
    INTEGRATION_DIRS["$name"]="$dir"
    INTEGRATION_REPOS["$name"]="$repo_url"
    INTEGRATION_BRANCHES["$name"]="$branch"
    INTEGRATION_RUNNERS["$name"]="$runner"
    INTEGRATION_DESCRIPTIONS["$name"]="$description"
    
    # CLI-Befehle registrieren wenn Registry verfügbar
    if declare -F register_command &>/dev/null; then
        local type_info="${INTEGRATION_TYPE_INFO[$type]:-🔌|Integration}"
        local emoji="${type_info%%|*}"
        
        # Sync-Befehl
        register_command "$name sync" "" "sync" \
            "$name_upper-Repository synchronisieren" \
            "SOT $name sync [--branch <b>]" \
            "SOT $name sync --branch develop"
    fi
}

# Listet alle aktiven Integrationen
list_integrations() {
    local name
    printf "\n  %sAktive Integrationen:%s\n" "${BOLD:-}" "${NC:-}"
    printf "  %s\n" "$(printf '─%.0s' {1..50})"
    
    if [[ ${#INTEGRATIONS[@]} -eq 0 ]]; then
        printf "  %sKeine Integrationen konfiguriert.%s\n\n" "${GREY:-}" "${NC:-}"
        return 0
    fi
    
    for name in "${!INTEGRATIONS[@]}"; do
        local type="${INTEGRATION_TYPES[$name]}"
        local dir="${INTEGRATION_DIRS[$name]}"
        local branch="${INTEGRATION_BRANCHES[$name]}"
        local desc="${INTEGRATION_DESCRIPTIONS[$name]}"
        local type_info="${INTEGRATION_TYPE_INFO[$type]:-🔌|Integration}"
        local emoji="${type_info%%|*}"
        local status_icon="○"
        local status_color="${GREY:-}"
        
        # Status prüfen
        if [[ -d "$dir/.git" ]]; then
            status_icon="●"
            status_color="${GREEN:-}"
        fi
        
        printf "  %s%s%s %s%-10s%s %s%s%s\n" \
            "$status_color" "$status_icon" "${NC:-}" \
            "${CYAN:-}" "$name" "${NC:-}" \
            "${GREY:-}" "$desc" "${NC:-}"
        printf "      %sTyp:%s %-12s %sVerzeichnis:%s %s\n" \
            "${GREY:-}" "${NC:-}" "$type" \
            "${GREY:-}" "${NC:-}" "$dir"
        printf "      %sBranch:%s %-10s %sStatus:%s %s\n\n" \
            "${GREY:-}" "${NC:-}" "$branch" \
            "${GREY:-}" "${NC:-}" \
            "$([[ -d "$dir/.git" ]] && echo "Synchronisiert" || echo "Nicht synchronisiert")"
    done
}

# =============================================================================
# Integration Operations
# =============================================================================

# Prüft ob eine Integration existiert
integration_exists() {
    local name="$1"
    [[ -n "${INTEGRATIONS[$name]:-}" ]]
}

# Holt Integration-Info
get_integration_info() {
    local name="$1"
    local field="$2"
    
    case "$field" in
        type)   echo "${INTEGRATION_TYPES[$name]:-}" ;;
        dir)    echo "${INTEGRATION_DIRS[$name]:-}" ;;
        repo)   echo "${INTEGRATION_REPOS[$name]:-}" ;;
        branch) echo "${INTEGRATION_BRANCHES[$name]:-}" ;;
        runner) echo "${INTEGRATION_RUNNERS[$name]:-}" ;;
        desc)   echo "${INTEGRATION_DESCRIPTIONS[$name]:-}" ;;
        *)      return 1 ;;
    esac
}

# Synchronisiert eine Integration (Clone oder Pull)
sync_integration() {
    local name="$1"
    local branch_override="${2:-}"
    
    if ! integration_exists "$name"; then
        err "Integration '$name' nicht gefunden oder deaktiviert."
        return 1
    fi
    
    local repo_url="${INTEGRATION_REPOS[$name]}"
    local dir="${INTEGRATION_DIRS[$name]}"
    local branch="${branch_override:-${INTEGRATION_BRANCHES[$name]}}"
    local name_upper="${name^^}"
    
    if [[ -z "$repo_url" ]]; then
        err "Keine Repository-URL für '$name' konfiguriert."
        return 1
    fi
    
    info "Synchronisiere ${CYAN:-}$name_upper${NC:-}..."
    printf "  %sRepository:%s %s\n" "${GREY:-}" "${NC:-}" "$repo_url"
    printf "  %sVerzeichnis:%s %s\n" "${GREY:-}" "${NC:-}" "$dir"
    printf "  %sBranch:%s %s\n\n" "${GREY:-}" "${NC:-}" "$branch"
    
    local timeout="${SOT_GIT_TIMEOUT:-120}"
    
    if [[ -d "$dir/.git" ]]; then
        # Update existierendes Repository
        info "Aktualisiere bestehendes Repository..."
        
        if ! run_with_timeout "$timeout" git -C "$dir" fetch --all --prune; then
            err "Git fetch fehlgeschlagen."
            return 1
        fi
        
        if ! run_with_timeout "$timeout" git -C "$dir" checkout "$branch"; then
            err "Konnte Branch '$branch' nicht auschecken."
            return 1
        fi
        
        if ! run_with_timeout "$timeout" git -C "$dir" pull origin "$branch"; then
            err "Git pull fehlgeschlagen."
            return 1
        fi
    else
        # Neues Repository klonen
        info "Klone Repository..."
        
        # Verzeichnis erstellen falls nötig
        if [[ ! -d "$(dirname "$dir")" ]]; then
            sudo mkdir -p "$(dirname "$dir")" 2>/dev/null || mkdir -p "$(dirname "$dir")"
        fi
        
        if ! run_with_timeout "$timeout" git clone --branch "$branch" "$repo_url" "$dir"; then
            err "Git clone fehlgeschlagen."
            return 1
        fi
    fi
    
    success "$name_upper erfolgreich synchronisiert!"
    return 0
}

# Führt den Runner einer Integration aus
run_integration() {
    local name="$1"
    shift
    local args=("$@")
    
    if ! integration_exists "$name"; then
        err "Integration '$name' nicht gefunden oder deaktiviert."
        return 1
    fi
    
    local dir="${INTEGRATION_DIRS[$name]}"
    local runner="${INTEGRATION_RUNNERS[$name]}"
    local runner_path="$dir/$runner"
    local name_upper="${name^^}"
    
    # Prüfen ob synchronisiert
    if [[ ! -d "$dir/.git" ]]; then
        warn "$name_upper nicht synchronisiert. Synchronisiere automatisch..."
        if ! sync_integration "$name"; then
            return 1
        fi
    fi
    
    # Runner prüfen
    if [[ ! -f "$runner_path" ]]; then
        err "Runner nicht gefunden: $runner_path"
        return 1
    fi
    
    if [[ ! -x "$runner_path" ]]; then
        chmod +x "$runner_path" 2>/dev/null || true
    fi
    
    # Umgebungsvariablen setzen
    export SOT_INTEGRATION_NAME="$name"
    export SOT_INTEGRATION_DIR="$dir"
    export SOT_INTEGRATION_TYPE="${INTEGRATION_TYPES[$name]}"
    
    # Runner ausführen
    info "Führe $name_upper aus..."
    "$runner_path" "${args[@]}"
}

# Validiert eine Integration
validate_integration() {
    local name="$1"
    local status=0
    
    if ! integration_exists "$name"; then
        err "Integration '$name' nicht konfiguriert."
        return 1
    fi
    
    local dir="${INTEGRATION_DIRS[$name]}"
    local branch="${INTEGRATION_BRANCHES[$name]}"
    local runner="${INTEGRATION_RUNNERS[$name]}"
    local name_upper="${name^^}"
    
    printf "  %s%s%s Integration:\n" "${CYAN:-}" "$name_upper" "${NC:-}"
    
    # Verzeichnis prüfen
    if [[ -d "$dir/.git" ]]; then
        printf "    %s✓%s Repository vorhanden\n" "${GREEN:-}" "${NC:-}"
        
        # Branch prüfen
        local current_branch
        current_branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        if [[ "$current_branch" == "$branch" ]]; then
            printf "    %s✓%s Korrekter Branch (%s)\n" "${GREEN:-}" "${NC:-}" "$branch"
        else
            printf "    %s!%s Falscher Branch: %s (erwartet: %s)\n" "${YELLOW:-}" "${NC:-}" "$current_branch" "$branch"
            status=1
        fi
        
        # Runner prüfen
        if [[ -x "$dir/$runner" ]]; then
            printf "    %s✓%s Runner ausführbar\n" "${GREEN:-}" "${NC:-}"
        elif [[ -f "$dir/$runner" ]]; then
            printf "    %s!%s Runner nicht ausführbar\n" "${YELLOW:-}" "${NC:-}"
            status=1
        else
            printf "    %s✗%s Runner nicht gefunden (%s)\n" "${RED:-}" "${NC:-}" "$runner"
            status=1
        fi
    else
        printf "    %s✗%s Nicht synchronisiert\n" "${RED:-}" "${NC:-}"
        status=1
    fi
    
    printf "\n"
    return $status
}

# Validiert alle Integrationen
validate_all_integrations() {
    local name
    local overall_status=0
    
    printf "\n  %sIntegration Validation%s\n" "${BOLD:-}" "${NC:-}"
    printf "  %s\n\n" "$(printf '─%.0s' {1..40})"
    
    if [[ ${#INTEGRATIONS[@]} -eq 0 ]]; then
        printf "  %sKeine Integrationen konfiguriert.%s\n\n" "${GREY:-}" "${NC:-}"
        return 0
    fi
    
    for name in "${!INTEGRATIONS[@]}"; do
        if ! validate_integration "$name"; then
            overall_status=1
        fi
    done
    
    if [[ $overall_status -eq 0 ]]; then
        success "Alle Integrationen OK!"
    else
        warn "Einige Integrationen haben Probleme."
    fi
    
    return $overall_status
}

# =============================================================================
# Integration Templates
# =============================================================================

# Generiert eine Beispiel-Konfiguration für eine neue Integration
generate_integration_config() {
    local name="$1"
    local type="${2:-custom}"
    local repo_url="${3:-https://github.com/example/$name.git}"
    local name_upper="${name^^}"
    
    cat << EOF
# $name_upper Integration
${name}:
  enabled: "true"
  repo_url: "$repo_url"
  dir: "/opt/$name_upper"
  branch: "main"
  type: "$type"
  runner: "runner.sh"
  description: "$name_upper Integration"
EOF

    if [[ "$type" == "ansible" ]]; then
        cat << EOF
  inventory_path: "inventory/hosts.ini"
  inventory_vars: "ssh_port,system_name"
EOF
    fi
}

# Zeigt Hilfe für das Integrations-System
show_integration_help() {
    cat << 'EOF'

  Integrations-System
  ═══════════════════

  SOT unterstützt beliebige externe Repository-Integrationen.
  
  Verfügbare Befehle:
    SOT <name> sync          Repository synchronisieren
    SOT <name> <args>        Integration ausführen
    SOT integrations list    Alle Integrationen auflisten
    SOT integrations validate Alle Integrationen prüfen

  Neue Integration hinzufügen:
    1. In config.yaml eintragen:
       
       myintegration:
         enabled: "true"
         repo_url: "https://github.com/..."
         dir: "/opt/MYINTEGRATION"
         branch: "main"
         type: "custom"   # ansible|terraform|custom|script
         runner: "runner.sh"
    
    2. Repository synchronisieren:
       SOT myintegration sync
    
    3. Integration nutzen:
       SOT myintegration <befehl>

  Unterstützte Typen:
    ansible    - Ansible Playbooks (mit Inventory-Support)
    terraform  - Terraform Module
    custom     - Eigene Runner-Skripte
    script     - Skript-Sammlungen

EOF
}

# =============================================================================
# CLI-Integration
# =============================================================================

# Handler für Integration-Befehle
handle_integration_command() {
    local name="$1"
    shift
    local subcommand="${1:-help}"
    shift || true
    
    case "$subcommand" in
        sync)
            local branch_override=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --branch|-b)
                        shift
                        branch_override="$1"
                        ;;
                esac
                shift || true
            done
            sync_integration "$name" "$branch_override"
            ;;
        validate)
            validate_integration "$name"
            ;;
        help|--help|-h)
            local name_upper="${name^^}"
            printf "\n  %s%s Integration%s\n" "${BOLD:-}" "$name_upper" "${NC:-}"
            printf "  %s\n\n" "$(printf '─%.0s' {1..40})"
            printf "  %sBefehle:%s\n" "${GREY:-}" "${NC:-}"
            printf "    SOT %s sync [--branch <b>]   Synchronisieren\n" "$name"
            printf "    SOT %s <args>                Ausführen\n" "$name"
            printf "    SOT %s validate              Validieren\n" "$name"
            printf "\n"
            ;;
        *)
            # An Runner weiterleiten
            run_integration "$name" "$subcommand" "$@"
            ;;
    esac
}

# Handler für 'SOT integrations' Befehle
handle_integrations_meta_command() {
    local subcommand="${1:-list}"
    shift || true
    
    case "$subcommand" in
        list|ls)
            list_integrations
            ;;
        validate|check)
            validate_all_integrations
            ;;
        help|--help|-h)
            show_integration_help
            ;;
        add)
            local name="${1:-}"
            local type="${2:-custom}"
            if [[ -z "$name" ]]; then
                err "Name erforderlich: SOT integrations add <name> [type]"
                return 1
            fi
            printf "\n  %sFüge diese Zeilen zu config.yaml hinzu:%s\n\n" "${YELLOW:-}" "${NC:-}"
            generate_integration_config "$name" "$type"
            printf "\n"
            ;;
        *)
            err "Unbekannter Befehl: $subcommand"
            show_integration_help
            return 1
            ;;
    esac
}
