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
# SOT_ROOT wird vom Setup-Script hier eingefügt:
# __SOT_ROOT_PLACEHOLDER__
set -euo pipefail

# =============================================================================
# Pfad-Initialisierung
# =============================================================================

# Standard-Installationspfad als Fallback
DEFAULT_SOT_ROOT="/opt/SOT"

# Wenn SOT_ROOT nicht gesetzt, versuche es zu finden
if [[ -z "${SOT_ROOT:-}" ]]; then
    # Prüfe bekannte Installationspfade
    if [[ -f "$DEFAULT_SOT_ROOT/lib/init.sh" ]]; then
        SOT_ROOT="$DEFAULT_SOT_ROOT"
    elif [[ -f "/opt/AAT/lib/init.sh" ]]; then
        SOT_ROOT="/opt/AAT"
    else
        # Letzter Versuch: Symlink auflösen
        _script="${BASH_SOURCE[0]}"
        if command -v realpath &>/dev/null && [[ -L "$_script" ]]; then
            _real="$(realpath "$_script" 2>/dev/null)" && SOT_ROOT="$(dirname "$(dirname "$_real")")"
        elif [[ -L "$_script" ]]; then
            _real="$(readlink -f "$_script" 2>/dev/null)" && SOT_ROOT="$(dirname "$(dirname "$_real")")"
        fi
    fi
fi

# Fallback wenn nichts gefunden
SOT_ROOT="${SOT_ROOT:-$DEFAULT_SOT_ROOT}"

# Prüfe ob SOT_ROOT gültig ist
if [[ ! -f "$SOT_ROOT/lib/init.sh" ]]; then
    echo "FEHLER: SOT Installation nicht gefunden!" >&2
    echo "Erwartet: $SOT_ROOT/lib/init.sh" >&2
    echo "Bitte SOT neu installieren oder SOT_ROOT setzen." >&2
    exit 1
fi

# Legacy-Kompatibilität
SCRIPT_ROOT="${SOT_ROOT}"

# Shared Libraries laden
# shellcheck source=../lib/init.sh
source "$SCRIPT_ROOT/lib/init.sh"
# shellcheck source=../lib/cli/registry.sh
source "$SCRIPT_ROOT/lib/cli/registry.sh"
# shellcheck source=../lib/plugins/manager.sh
source "$SCRIPT_ROOT/lib/plugins/manager.sh"

# =============================================================================
# Konfiguration laden
# =============================================================================
CONFIG_FILE=${CONFIG_FILE:-"$SCRIPT_ROOT/config/default_config.yml"}

if [[ -f "$CONFIG_FILE" ]]; then
    parse_yaml_to_vars "$CONFIG_FILE"
fi

# Standardwerte setzen
DEFAULT_ROOT="$SCRIPT_ROOT"
modules_dir="${modules_dir:-$DEFAULT_ROOT/modules}"
commands_dir="${commands_dir:-$DEFAULT_ROOT/commands}"
clone_dir="${clone_dir:-$DEFAULT_ROOT}"
opt_data_dir="${opt_data_dir:-$DEFAULT_ROOT/.sot-data}"
vault_file="${vault_file:-$DEFAULT_ROOT/templates/vault.j2}"
vault_secret="${vault_secret:-local-secret}"
username="${username:-${USER:-sot-user}}"
systemlink_path="${systemlink_path:-/usr/local/bin/SOT}"
log_file="${log_file:-}"
branch="${branch:-main}"

# Verzeichnisse erstellen
mkdir -p "$opt_data_dir" 2>/dev/null || true

# Placeholder-Werte ersetzen
[[ "$modules_dir" == *"__GENERATE_"* ]] && modules_dir="$DEFAULT_ROOT/modules"
[[ "$commands_dir" == *"__GENERATE_"* ]] && commands_dir="$DEFAULT_ROOT/commands"
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
# Plugins & Extensions entdecken
# =============================================================================

# Plugin-System initialisieren mit korrektem Pfad
MODULES_DIR="$modules_dir"
discover_plugins

# =============================================================================
# CLI-Befehle registrieren
# =============================================================================
init_command_registry() {
    # System-Befehle
    register_command "bootstrap" "$commands_dir/bootstrap.sh" "system" \
        "Server-Konfiguration ausführen" \
        "SOT bootstrap [--check] [--tags <tags>]" \
        "SOT bootstrap --tags ssh,firewall"
    
    # Vault-Befehle
    register_command "vault" "$commands_dir/vault.sh" "vault" \
        "Vault interaktiv bearbeiten" \
        "SOT vault [view|edit|rekey]" \
        "SOT vault edit"
    
    # Runner
    register_command "runner" "$commands_dir/runner.sh" "run" \
        "Ansible/Terraform Playbooks ausführen" \
        "SOT runner <integration> <playbook> [options]" \
        "SOT runner aat site.yml --tags setup"
    
    # Maintenance
    register_command "update" "$commands_dir/maintenance/update.sh" "maintenance" \
        "SOT aktualisieren" \
        "SOT update [--force]" \
        "SOT update"
    
    register_command "delete" "$commands_dir/maintenance/delete.sh" "maintenance" \
        "SOT entfernen" \
        "SOT delete [--no-backup]" \
        "SOT delete"
    
    # Legacy-Kompatibilität: alte Integrations-Befehle über Aliasse gehandhabt
    
    # Plugin-Befehle
    register_command "plugins" "" "plugins" \
        "Plugin-System verwalten" \
        "SOT plugins [list|info|enable|disable] [name]" \
        "SOT plugins list"
    
    # Dynamische Plugin-Befehle registrieren
    local plugin
    for plugin in "${DISCOVERED_PLUGINS[@]}"; do
        local plugin_desc="${PLUGIN_DESCRIPTIONS[$plugin]:-$plugin Plugin}"
        local plugin_cmds="${PLUGIN_COMMANDS[$plugin]:-}"
        
        # Haupt-Plugin-Befehl
        register_command "$plugin" "" "plugins" \
            "$plugin_desc" \
            "SOT $plugin [command] [options]" \
            "SOT $plugin info"
        
        # Sub-Commands des Plugins
        if [[ -n "$plugin_cmds" ]]; then
            for cmd in $plugin_cmds; do
                register_command "$plugin $cmd" "" "plugins" \
                    "$plugin: $cmd" \
                    "SOT $plugin $cmd [options]" \
                    "SOT $plugin $cmd"
            done
        fi
        
        # Install-Befehl falls Installer vorhanden
        if [[ -n "${PLUGIN_INSTALLERS[$plugin]:-}" ]]; then
            register_command "$plugin install" "" "plugins" \
                "$plugin installieren" \
                "SOT $plugin install [options]" \
                "SOT $plugin install"
        fi
    done
    
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
    printf '%s' "${CYAN:-}"
    cat << 'BANNER'

   ███████╗ ██████╗ ████████╗
   ██╔════╝██╔═══██╗╚══██╔══╝
   ███████╗██║   ██║   ██║   
   ╚════██║██║   ██║   ██║   
   ███████║╚██████╔╝   ██║   
   ╚══════╝ ╚═════╝    ╚═╝   

BANNER
    printf '%s' "${NC:-}"
    printf '  %sServer Operation Toolkit%s\n' "${GREY:-}" "${NC:-}"
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
    printf '  %sTipp: Mit%s %sSOT --interactive%s %sdas interaktive Menü starten%s\n\n' \
        "${GREY:-}" "${NC:-}" "${YELLOW:-}" "${NC:-}" "${GREY:-}" "${NC:-}"
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
        
        local candidate="$commands_dir/$joined.sh"
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
    printf '\n  %sVerfügbare Befehle:%s SOT help\n\n' "${GREY:-}" "${NC:-}"
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
            
            printf '\n  %s[Enter] für Menü, [q] zum Beenden%s ' "${GREY:-}" "${NC:-}"
            read -r -n1 key
            [[ "$key" == "q" ]] && break
            clear
            show_banner
        else
            break
        fi
    done
    
    printf '\n  %sAuf Wiedersehen!%s\n\n' "${GREY:-}" "${NC:-}"
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
        
        # Legacy: integrations -> extensions redirect
        integrations)
            shift
            execute_script "$commands_dir/extensions.sh" "$@"
            ;;
        
        # Plugin-Meta-Befehl
        plugins)
            shift
            handle_plugins_command "$@"
            ;;
        
        # Validate-Shortcut -> extensions validate
        validate)
            execute_script "$commands_dir/extensions.sh" validate
            ;;
        
        # Shortcuts
        update)
            shift
            execute_script "$commands_dir/maintenance/update.sh" "$@"
            ;;
        
        delete)
            shift
            execute_script "$commands_dir/maintenance/delete.sh" "$@"
            ;;
        
        # Dynamische Handler
        *)
            local cmd="$1"
            
            # Prüfen ob es ein Plugin ist
            if plugin_exists "$cmd"; then
                shift
                if [[ $# -eq 0 ]]; then
                    show_plugin_info "$cmd"
                elif [[ "$1" == "install" ]]; then
                    shift
                    install_plugin "$cmd" "$@"
                else
                    run_plugin_command "$cmd" "$@"
                fi
            else
                # Fallback: Standard-Befehlsauflösung
                resolve_and_execute "$@"
            fi
            ;;
    esac
}

main "$@"
