#!/usr/bin/env bash
# =============================================================================
#  _____ _____ _____    _____  _      _____ 
# /  ___|  _  |_   _|  /  __ \| |    |_   _|
# \ `--.| | | | | |    | /  \/| |      | |  
#  `--. \ | | | | |    | |    | |      | |  
# /\__/ / \_/ / | |    | \__/\| |____ _| |_ 
# \____/ \___/  \_/     \____/\_____/ \___/ 
#
# Server Operation Toolkit - Command Line Interface v2.0
# =============================================================================
set -euo pipefail

# =============================================================================
# Pfad-Initialisierung
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Shared Libraries laden
# shellcheck source=../lib/init.sh
source "$SCRIPT_ROOT/lib/init.sh"
# shellcheck source=../lib/cli_registry.sh
source "$SCRIPT_ROOT/lib/cli_registry.sh"

# =============================================================================
# Konfiguration laden
# =============================================================================
CONFIG_FILE=${CONFIG_FILE:-"$SCRIPT_ROOT/services/default_config.yml"}

if [[ -f "$CONFIG_FILE" ]]; then
    parse_yaml_to_vars "$CONFIG_FILE"
fi

# Standardwerte setzen
DEFAULT_ROOT="$SCRIPT_ROOT"
modules_dir="${modules_dir:-$DEFAULT_ROOT/modules}"
scripts_dir="${scripts_dir:-$DEFAULT_ROOT/scripts}"
clone_dir="${clone_dir:-$DEFAULT_ROOT}"
opt_data_dir="${opt_data_dir:-$DEFAULT_ROOT/.sot-data}"
vault_file="${vault_file:-$DEFAULT_ROOT/setup/vault_template.j2}"
vault_secret="${vault_secret:-local-secret}"
username="${username:-${USER:-sot-user}}"
systemlink_path="${systemlink_path:-/usr/local/bin/SOT}"
log_file="${log_file:-}"
branch="${branch:-main}"

# Verzeichnisse erstellen
mkdir -p "$opt_data_dir" 2>/dev/null || true

# Placeholder-Werte ersetzen
[[ "$modules_dir" == *"__GENERATE_"* ]] && modules_dir="$DEFAULT_ROOT/modules"
[[ "$scripts_dir" == *"__GENERATE_"* ]] && scripts_dir="$DEFAULT_ROOT/scripts"
[[ "$clone_dir" == *"__GENERATE_"* ]] && clone_dir="$DEFAULT_ROOT"

# CLI Metadata für Skript-Aufrufe
CLI_METADATA_ARGS=(
    "$modules_dir"
    "$CONFIG_FILE"
    "$username"
    "$vault_file"
    "$vault_secret"
    "$opt_data_dir"
    "$clone_dir"
    "${systemlink_path:-}"
    "${log_file:-}"
    "${branch:-}"
)

# =============================================================================
# CLI-Befehle registrieren
# =============================================================================
init_command_registry() {
    # System-Befehle
    register_command "setup" "$scripts_dir/setup.sh" "system" \
        "Server-Konfiguration ausführen" \
        "SOT setup [--check] [--tags <tags>]" \
        "SOT setup --tags ssh,firewall"
    
    # Vault-Befehle
    register_command "vault" "$scripts_dir/vault.sh" "vault" \
        "Vault interaktiv bearbeiten" \
        "SOT vault [view|edit|rekey]" \
        "SOT vault edit"
    
    # Runner
    register_command "runner" "$scripts_dir/runner.sh" "run" \
        "Ansible/Terraform Playbooks ausführen" \
        "SOT runner <aat|tid> <playbook> [options]" \
        "SOT runner aat site.yml --tags setup"
    
    # Maintenance
    register_command "update" "$scripts_dir/maintenance/update.sh" "maintenance" \
        "SOT aktualisieren" \
        "SOT update [--force]" \
        "SOT update"
    
    register_command "delete" "$scripts_dir/maintenance/delete.sh" "maintenance" \
        "SOT entfernen" \
        "SOT delete [--no-backup]" \
        "SOT delete"
    
    # Sync-Befehle
    register_command "aat sync" "$scripts_dir/integrations/aat_sync.sh" "sync" \
        "AAT-Repository synchronisieren" \
        "SOT aat sync [--branch <b>]" \
        "SOT aat sync --branch develop"
    
    register_command "tid sync" "$scripts_dir/integrations/tid_sync.sh" "sync" \
        "TID-Repository synchronisieren" \
        "SOT tid sync [--branch <b>]" \
        "SOT tid sync"
    
    register_command "validate" "$scripts_dir/integrations/validate_sync.sh" "sync" \
        "Integration-Status validieren" \
        "SOT validate" \
        "SOT validate"
    
    # Info
    register_command "help" "" "info" \
        "Hilfe anzeigen" \
        "SOT help [<command>]" \
        "SOT help setup"
    
    register_command "version" "" "info" \
        "Version anzeigen" \
        "SOT version" \
        "SOT version"
}

# =============================================================================
# Banner & Version
# =============================================================================
show_banner() {
    printf "${CYAN:-}"
    cat << 'BANNER'

   ███████╗ ██████╗ ████████╗
   ██╔════╝██╔═══██╗╚══██╔══╝
   ███████╗██║   ██║   ██║   
   ╚════██║██║   ██║   ██║   
   ███████║╚██████╔╝   ██║   
   ╚══════╝ ╚═════╝    ╚═╝   

BANNER
    printf "${NC:-}"
    printf "  ${GREY:-}Server Operation Toolkit${NC:-}\n"
}

show_version() {
    local version="2.0.0"
    local commit_hash="unknown"
    
    if [[ -d "$SCRIPT_ROOT/.git" ]]; then
        commit_hash=$(git -C "$SCRIPT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi
    
    printf "\n  ${CYAN:-}SOT${NC:-} ${BOLD:-}v%s${NC:-} ${GREY:-}(%s)${NC:-}\n\n" "$version" "$commit_hash"
}

# =============================================================================
# Hilfe-System
# =============================================================================
show_help() {
    local cmd="${1:-}"
    
    if [[ -n "$cmd" && "$cmd" != "help" ]]; then
        show_command_detail "$cmd"
        return $?
    fi
    
    show_banner
    show_categorized_help
    
    # Quickstart-Tipps
    printf "  ${GREY:-}Tipp: Mit${NC:-} ${YELLOW:-}SOT --interactive${NC:-} ${GREY:-}das interaktive Menü starten${NC:-}\n\n"
}

show_legacy_command_help() {
    local command_path="$1"
    
    if [[ -f "$command_path" ]] && grep -q '^##' "$command_path"; then
        awk '/^##/{sub(/^##[[:space:]]*/, ""); print}' "$command_path"
        return 0
    fi
    
    echo "Keine detaillierte Hilfe verfügbar."
    return 0
}

# =============================================================================
# Integration-Runner (AAT/TID)
# =============================================================================
invoke_integration_runner() {
    local integration="$1"
    shift || true
    
    local enabled_var="${integration}_enabled"
    local dir_var="${integration}_dir"
    local branch_var="${integration}_branch"
    local inventory_path_var="${integration}_inventory_path"
    local inventory_vars_var="${integration}_inventory_vars"
    
    local repo_dir="${!dir_var:-}"
    local enabled_value="${!enabled_var:-true}"
    local branch_value="${!branch_var:-}"
    local inventory_path_value="${!inventory_path_var:-host.ini}"
    local inventory_vars_value="${!inventory_vars_var:-}"
    local sync_script="$SCRIPT_ROOT/scripts/integrations/${integration}_sync.sh"
    
    # Defaults
    case "$integration" in
        aat)
            [[ -z "$repo_dir" || "$repo_dir" == *"__GENERATE_"* ]] && repo_dir="/opt/AAT"
            [[ -z "$branch_value" || "$branch_value" == *"__GENERATE_"* ]] && branch_value="main"
            ;;
        tid)
            [[ -z "$repo_dir" || "$repo_dir" == *"__GENERATE_"* ]] && repo_dir="/opt/TID"
            [[ -z "$branch_value" || "$branch_value" == *"__GENERATE_"* ]] && branch_value="main"
            ;;
        *)
            err "Unbekannte Integration: '$integration'"
            return 1
            ;;
    esac
    
    if ! is_true "$enabled_value"; then
        warn "${integration^^} Integration ist in config.yaml deaktiviert."
        return 1
    fi
    
    local runner_path="$repo_dir/runner.sh"
    local synced=false
    
    # Auto-Sync wenn nötig
    if [[ ! -x "$runner_path" || ! -d "$repo_dir" ]]; then
        if [[ -x "$sync_script" ]]; then
            info "Synchronisiere ${integration^^} Repository..."
            local -a sync_args=("$sync_script")
            [[ -n "$branch_value" ]] && sync_args+=("--branch" "$branch_value")
            sync_args+=("${CLI_METADATA_ARGS[@]}")
            if ! "${sync_args[@]}"; then
                err "Synchronisierung von ${integration^^} fehlgeschlagen."
                return 1
            fi
            synced=true
        fi
    fi
    
    [[ -f "$runner_path" && ! -x "$runner_path" ]] && chmod +x "$runner_path" 2>/dev/null || true
    
    if [[ ! -x "$runner_path" ]]; then
        err "runner.sh nicht gefunden für ${integration^^} unter $repo_dir"
        info "Führe 'SOT ${integration} sync' aus."
        return 1
    fi
    
    # Validierung nach Sync
    if $synced; then
        local validate_script="$SCRIPT_ROOT/scripts/integrations/validate_sync.sh"
        if [[ -x "$validate_script" ]]; then
            "$validate_script" "$CONFIG_FILE" 2>/dev/null || warn "Validierung meldet Probleme."
        fi
    fi
    
    # Environment exportieren
    export SOT_CONFIG_FILE="$CONFIG_FILE"
    export SOT_MODULES_DIR="$modules_dir"
    export SOT_SCRIPTS_DIR="$scripts_dir"
    export SOT_OPT_DATA_DIR="$opt_data_dir"
    export SOT_CLONE_DIR="$clone_dir"
    export SOT_USERNAME="$username"
    export SOT_BRANCH="${branch:-}"
    export SOT_INTEGRATION_NAME="$integration"
    
    # Inventory-Handling
    local previous_ansible_inventory="${ANSIBLE_INVENTORY:-}"
    local temp_inventory=""
    local inventory_source=""
    
    if [[ -n "$inventory_path_value" ]]; then
        inventory_source="${inventory_path_value##/*}"
        [[ "$inventory_path_value" != /* ]] && inventory_source="$repo_dir/$inventory_path_value"
    fi
    
    if [[ -f "$inventory_source" ]]; then
        temp_inventory=$(mktemp "${TMPDIR:-/tmp}/sot_${integration}_inventory_XXXXXX")
        cp "$inventory_source" "$temp_inventory"
        
        local appended_vars=false
        for var_name in ${inventory_vars_value//,/ }; do
            [[ -z "$var_name" ]] && continue
            local var_value="${!var_name:-}"
            if [[ -n "$var_value" ]]; then
                [[ $appended_vars == false ]] && { printf '\n[all:vars]\n' >> "$temp_inventory"; appended_vars=true; }
                printf '%s=%s\n' "$var_name" "$var_value" >> "$temp_inventory"
            fi
        done
        
        [[ -n "$temp_inventory" ]] && export ANSIBLE_INVENTORY="$temp_inventory"
    fi
    
    # Runner ausführen
    local -a runner_cmd=("$runner_path")
    [[ $# -gt 0 ]] && runner_cmd+=("$@") || runner_cmd+=("--help")
    
    log_command "${runner_cmd[*]}"
    local result=0
    "${runner_cmd[@]}" || result=$?
    
    # Cleanup
    if [[ -n "$temp_inventory" ]]; then
        rm -f "$temp_inventory"
        [[ -n "$previous_ansible_inventory" ]] && export ANSIBLE_INVENTORY="$previous_ansible_inventory" || unset ANSIBLE_INVENTORY
    fi
    
    return "$result"
}

# =============================================================================
# Befehlsausführung
# =============================================================================
execute_script() {
    local script_path="$1"
    shift
    
    [[ ! -f "$script_path" ]] && return 1
    [[ ! -x "$script_path" ]] && chmod +x "$script_path"
    
    log_command "$script_path $*"
    "$script_path" "$@" "${CLI_METADATA_ARGS[@]}"
}

resolve_command_path() {
    local -n _resolved=$1
    local -n _consumed=$2
    shift 2
    local args=("$@")
    
    _resolved=""
    _consumed=0
    
    for ((i = ${#args[@]}; i > 0; i--)); do
        local joined="${args[0]}"
        for part in "${args[@]:1:$((i-1))}"; do
            joined="$joined/$part"
        done
        
        local candidate="$scripts_dir/$joined.sh"
        if [[ -f "$candidate" ]]; then
            _resolved="$candidate"
            _consumed=$i
            return 0
        fi
    done
    
    return 1
}

resolve_and_execute() {
    local -a user_args=("$@")
    local cmd_name found_cmd=""
    
    # Registrierte Befehle prüfen
    for ((i=${#user_args[@]}; i>0; i--)); do
        cmd_name="${user_args[*]:0:i}"
        if [[ -n "${CLI_COMMANDS[$cmd_name]:-}" ]]; then
            found_cmd="${CLI_COMMANDS[$cmd_name]}"
            execute_script "$found_cmd" "${user_args[@]:i}"
            return $?
        fi
    done
    
    # Fallback: Direkte Pfad-Auflösung
    local COMMAND_PATH="" consumed=0
    if resolve_command_path COMMAND_PATH consumed "${user_args[@]}"; then
        execute_script "$COMMAND_PATH" "${user_args[@]:$consumed}"
        return $?
    fi
    
    err "Befehl '${user_args[*]}' nicht gefunden."
    printf "\n  ${GREY:-}Verfügbare Befehle:${NC:-} SOT help\n\n"
    return 127
}

# =============================================================================
# Interaktives Menü
# =============================================================================
run_interactive_mode() {
    clear
    show_banner
    
    while true; do
        local selected
        if show_interactive_menu; then
            read -r selected
            [[ -z "$selected" || "$selected" == "0" ]] && break
            
            # Befehl aus Menü ausführen
            local idx=1
            for cmd in $(printf '%s\n' "${!CLI_COMMANDS[@]}" | sort); do
                if [[ "$idx" == "$selected" ]]; then
                    printf "\n  ${GREEN:-}▶${NC:-} Führe aus: ${CYAN:-}%s${NC:-}\n\n" "$cmd"
                    resolve_and_execute "$cmd"
                    break
                fi
                ((idx++))
            done
            
            printf "\n  ${GREY:-}[Enter] für Menü, [q] zum Beenden${NC:-} "
            read -r -n1 key
            [[ "$key" == "q" ]] && break
            clear
            show_banner
        else
            break
        fi
    done
    
    printf "\n  ${GREY:-}Auf Wiedersehen!${NC:-}\n\n"
}

# =============================================================================
# Hauptprogramm
# =============================================================================
main() {
    # Registry initialisieren
    init_command_registry
    
    # Keine Argumente -> Hilfe
    if [[ $# -eq 0 ]]; then
        show_help
        return 0
    fi
    
    case "$1" in
        # Meta-Befehle
        -h|--help|help)
            shift
            show_help "$@"
            ;;
        
        -v|--version|version)
            show_version
            ;;
        
        -i|--interactive)
            run_interactive_mode
            ;;
        
        --completion)
            shift
            generate_completion "${1:-bash}"
            ;;
        
        # Integration-Befehle
        aat|tid)
            local integration="$1"
            shift
            
            if [[ "${1:-}" == "sync" ]]; then
                shift
                local sync_script="$scripts_dir/integrations/${integration}_sync.sh"
                execute_script "$sync_script" "$@"
            else
                invoke_integration_runner "$integration" "$@"
            fi
            ;;
        
        # Shortcuts
        update)
            shift
            execute_script "$scripts_dir/maintenance/update.sh" "$@"
            ;;
        
        delete)
            shift
            execute_script "$scripts_dir/maintenance/delete.sh" "$@"
            ;;
        
        # Alle anderen
        *)
            resolve_and_execute "$@"
            ;;
    esac
}

main "$@"
