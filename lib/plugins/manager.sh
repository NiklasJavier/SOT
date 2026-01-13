#!/usr/bin/env bash
# =============================================================================
# SOT Plugin System
# =============================================================================
# Dynamische Modul-Erkennung und -Verwaltung
#
# Features:
#   - Automatische Plugin-Discovery aus modules/
#   - Metadaten-basierte Konfiguration (module.yml)
#   - Lifecycle-Hooks (install, uninstall, enable, disable)
#   - CLI-Befehlsregistrierung pro Plugin
#
# Usage:
#   source "$SOT_LIB_DIR/plugins.sh"
#   discover_plugins
#   list_plugins
# =============================================================================

# Prevent multiple sourcing
[[ -n "${_SOT_PLUGINS_LOADED:-}" ]] && return 0
_SOT_PLUGINS_LOADED=1

# =============================================================================
# Plugin Registry
# =============================================================================

# Assoziative Arrays für Plugin-Daten
declare -gA PLUGIN_NAMES=()           # name -> display_name
declare -gA PLUGIN_DESCRIPTIONS=()    # name -> description
declare -gA PLUGIN_VERSIONS=()        # name -> version
declare -gA PLUGIN_TYPES=()           # name -> type (tool|service|integration)
declare -gA PLUGIN_PATHS=()           # name -> path to plugin directory
declare -gA PLUGIN_ENABLED=()         # name -> true/false
declare -gA PLUGIN_INSTALLERS=()      # name -> installer script path
declare -gA PLUGIN_COMMANDS=()        # name -> space-separated command list
declare -gA PLUGIN_HOOKS=()           # name -> hooks directory
declare -gA PLUGIN_DEPENDENCIES=()    # name -> space-separated dependency list

# Liste aller entdeckten Plugins
declare -ga DISCOVERED_PLUGINS=()

# =============================================================================
# YAML Parser für module.yml
# =============================================================================

# Parst eine einfache module.yml/plugin.yml Datei
# Arguments:
#   $1 - Pfad zur YAML-Datei
#   $2 - Name des assoziativen Arrays für Ergebnisse
parse_plugin_yaml() {
    local file="$1"
    local -n result_array="$2"
    
    [[ ! -f "$file" ]] && return 1
    
    local current_section=""
    local line key value
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Kommentare und leere Zeilen überspringen
        line="${line%%#*}"
        [[ -z "${line//[[:space:]]/}" ]] && continue
        
        # Section erkennen (z.B. "commands:")
        if [[ "$line" =~ ^([a-zA-Z_]+):$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi
        
        # Key-Value Paare
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_]+):[[:space:]]*(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            # Quotes entfernen
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            
            if [[ -n "$current_section" ]]; then
                result_array["${current_section}_${key}"]="$value"
            else
                result_array["$key"]="$value"
            fi
        fi
        
        # Listen-Items (- item)
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.+)$ && -n "$current_section" ]]; then
            local item="${BASH_REMATCH[1]}"
            item="${item#\"}"
            item="${item%\"}"
            
            local existing="${result_array[${current_section}]:-}"
            if [[ -z "$existing" ]]; then
                result_array["$current_section"]="$item"
            else
                result_array["$current_section"]="$existing $item"
            fi
        fi
    done < "$file"
    
    return 0
}

# =============================================================================
# Plugin Discovery
# =============================================================================

# Entdeckt alle Plugins im modules/ Verzeichnis
discover_plugins() {
    local modules_dir="${MODULES_DIR:-${SOT_ROOT:-/etc/DevOpsToolkit}/modules}"
    
    DISCOVERED_PLUGINS=()
    
    [[ ! -d "$modules_dir" ]] && return 0
    
    local plugin_dir plugin_name
    for plugin_dir in "$modules_dir"/*/; do
        [[ ! -d "$plugin_dir" ]] && continue
        
        plugin_name=$(basename "$plugin_dir")
        
        # Plugin registrieren
        if ! register_plugin "$plugin_name" "$plugin_dir"; then
            continue
        fi
        
        DISCOVERED_PLUGINS+=("$plugin_name")
    done
    
    return 0
}

# Registriert ein einzelnes Plugin
# Arguments:
#   $1 - Plugin-Name
#   $2 - Plugin-Verzeichnis
register_plugin() {
    local name="$1"
    local path="$2"
    
    # Metadaten-Datei suchen (module.yml bevorzugt wegen Schema-Konflikten mit plugin.yml)
    local meta_file=""
    for candidate in "module.yml" "module.yaml" "plugin.yml" "plugin.yaml"; do
        if [[ -f "${path}${candidate}" ]]; then
            meta_file="${path}${candidate}"
            break
        fi
    done
    
    # Pfad speichern
    PLUGIN_PATHS["$name"]="$path"
    
    if [[ -n "$meta_file" ]]; then
        # Metadaten aus YAML laden
        declare -A meta=()
        parse_plugin_yaml "$meta_file" meta
        
        PLUGIN_NAMES["$name"]="${meta[name]:-$name}"
        PLUGIN_DESCRIPTIONS["$name"]="${meta[description]:-No description}"
        PLUGIN_VERSIONS["$name"]="${meta[version]:-1.0.0}"
        PLUGIN_TYPES["$name"]="${meta[type]:-tool}"
        PLUGIN_ENABLED["$name"]="${meta[enabled]:-true}"
        PLUGIN_INSTALLERS["$name"]="${meta[installer]:-}"
        PLUGIN_COMMANDS["$name"]="${meta[commands]:-}"
        PLUGIN_DEPENDENCIES["$name"]="${meta[dependencies]:-}"
        
        # Hooks-Verzeichnis
        if [[ -d "${path}hooks" ]]; then
            PLUGIN_HOOKS["$name"]="${path}hooks"
        fi
    else
        # Fallback: Auto-Discovery ohne Metadaten
        PLUGIN_NAMES["$name"]="${name^}"  # Capitalize
        PLUGIN_DESCRIPTIONS["$name"]="$name module (auto-discovered)"
        PLUGIN_VERSIONS["$name"]="1.0.0"
        PLUGIN_TYPES["$name"]="tool"
        PLUGIN_ENABLED["$name"]="true"
        
        # Installer-Script automatisch erkennen (neue Struktur zuerst)
        if [[ -f "${path}install.sh" ]]; then
            PLUGIN_INSTALLERS["$name"]="${path}install.sh"
        elif [[ -f "${path}install_${name}.sh" ]]; then
            PLUGIN_INSTALLERS["$name"]="${path}install_${name}.sh"
        fi
        
        # Commands aus commands/ Verzeichnis erkennen (neue Struktur)
        local cmds=""
        if [[ -d "${path}commands" ]]; then
            for script in "${path}commands"/*.sh; do
                [[ ! -f "$script" ]] && continue
                local script_name=$(basename "$script" .sh)
                cmds+="${script_name} "
            done
        else
            # Fallback: alte Struktur - Scripts im Root
            for script in "${path}"*.sh; do
                [[ ! -f "$script" ]] && continue
                local script_name=$(basename "$script" .sh)
                # Install-Scripts überspringen
                [[ "$script_name" == "install"* ]] && continue
                cmds+="${script_name} "
            done
        fi
        PLUGIN_COMMANDS["$name"]="${cmds% }"
    fi
    
    return 0
}

# =============================================================================
# Plugin Abfragen
# =============================================================================

# Prüft ob ein Plugin existiert
plugin_exists() {
    local name="$1"
    [[ -n "${PLUGIN_PATHS[$name]:-}" ]]
}

# Prüft ob ein Plugin aktiviert ist
plugin_enabled() {
    local name="$1"
    [[ "${PLUGIN_ENABLED[$name]:-false}" == "true" ]]
}

# Gibt den Pfad eines Plugins zurück
get_plugin_path() {
    local name="$1"
    echo "${PLUGIN_PATHS[$name]:-}"
}

# Gibt alle aktivierten Plugins zurück
get_enabled_plugins() {
    local plugin
    for plugin in "${DISCOVERED_PLUGINS[@]}"; do
        plugin_enabled "$plugin" && echo "$plugin"
    done
}

# =============================================================================
# Plugin Lifecycle
# =============================================================================

# Führt den Installer eines Plugins aus
install_plugin() {
    local name="$1"
    shift
    
    if ! plugin_exists "$name"; then
        err "Plugin '$name' nicht gefunden"
        return 1
    fi
    
    local installer="${PLUGIN_INSTALLERS[$name]:-}"
    if [[ -z "$installer" ]]; then
        warn "Kein Installer für Plugin '$name' definiert"
        return 1
    fi
    
    if [[ ! -f "$installer" ]]; then
        err "Installer nicht gefunden: $installer"
        return 1
    fi
    
    # Pre-Install Hook
    run_plugin_hook "$name" "pre-install"
    
    info "Installiere Plugin: ${PLUGIN_NAMES[$name]}"
    
    chmod +x "$installer"
    if "$installer" "$@"; then
        success "Plugin '$name' erfolgreich installiert"
        run_plugin_hook "$name" "post-install"
        return 0
    else
        err "Installation von '$name' fehlgeschlagen"
        return 1
    fi
}

# Aktiviert ein Plugin
enable_plugin() {
    local name="$1"
    
    if ! plugin_exists "$name"; then
        err "Plugin '$name' nicht gefunden"
        return 1
    fi
    
    PLUGIN_ENABLED["$name"]="true"
    
    # In Config speichern (falls Config-System verfügbar)
    if declare -f save_plugin_state &>/dev/null; then
        save_plugin_state "$name" "enabled" "true"
    fi
    
    run_plugin_hook "$name" "enable"
    success "Plugin '$name' aktiviert"
}

# Deaktiviert ein Plugin
disable_plugin() {
    local name="$1"
    
    if ! plugin_exists "$name"; then
        err "Plugin '$name' nicht gefunden"
        return 1
    fi
    
    PLUGIN_ENABLED["$name"]="false"
    
    if declare -f save_plugin_state &>/dev/null; then
        save_plugin_state "$name" "enabled" "false"
    fi
    
    run_plugin_hook "$name" "disable"
    warn "Plugin '$name' deaktiviert"
}

# =============================================================================
# Plugin Hooks
# =============================================================================

# Führt einen Hook für ein Plugin aus
run_plugin_hook() {
    local name="$1"
    local hook="$2"
    shift 2
    
    local hooks_dir="${PLUGIN_HOOKS[$name]:-}"
    [[ -z "$hooks_dir" ]] && return 0
    
    # Einzelnes Hook-Script
    local hook_script="${hooks_dir}/${hook}.sh"
    if [[ -f "$hook_script" && -x "$hook_script" ]]; then
        "$hook_script" "$@"
        return $?
    fi
    
    # Hook-Verzeichnis mit mehreren Scripts
    local hook_dir="${hooks_dir}/${hook}.d"
    if [[ -d "$hook_dir" ]]; then
        local script
        for script in "$hook_dir"/*.sh; do
            [[ ! -f "$script" ]] && continue
            chmod +x "$script"
            "$script" "$@"
        done
    fi
    
    return 0
}

# =============================================================================
# Plugin Commands
# =============================================================================

# Führt einen Befehl eines Plugins aus
run_plugin_command() {
    local name="$1"
    local command="$2"
    shift 2
    
    if ! plugin_exists "$name"; then
        err "Plugin '$name' nicht gefunden"
        return 1
    fi
    
    if ! plugin_enabled "$name"; then
        err "Plugin '$name' ist deaktiviert"
        return 1
    fi
    
    local plugin_path="${PLUGIN_PATHS[$name]}"
    local script_path=""
    
    # Script finden (neue Struktur: commands/ Verzeichnis zuerst)
    for candidate in \
        "${plugin_path}commands/${command}.sh" \
        "${plugin_path}commands/${command}" \
        "${plugin_path}${command}.sh" \
        "${plugin_path}${command}"; do
        if [[ -f "$candidate" ]]; then
            script_path="$candidate"
            break
        fi
    done
    
    if [[ -z "$script_path" ]]; then
        err "Befehl '$command' für Plugin '$name' nicht gefunden"
        return 1
    fi
    
    # Ausführbar machen falls nötig
    [[ ! -x "$script_path" ]] && chmod +x "$script_path"
    
    # Pre-Command Hook
    run_plugin_hook "$name" "pre-${command}"
    
    # Befehl ausführen
    "$script_path" "$@"
    local result=$?
    
    # Post-Command Hook
    run_plugin_hook "$name" "post-${command}"
    
    return $result
}

# =============================================================================
# CLI Integration
# =============================================================================

# Zeigt alle Plugins an
show_plugins_list() {
    printf '\n  %sInstallierte Plugins:%s\n' "${BOLD:-}" "${NC:-}"
    printf '  %s\n' "──────────────────────────────────────────────────"
    
    if [[ ${#DISCOVERED_PLUGINS[@]} -eq 0 ]]; then
        printf '  %sKeine Plugins gefunden%s\n\n' "${GREY:-}" "${NC:-}"
        return 0
    fi
    
    local plugin status_icon status_color
    for plugin in "${DISCOVERED_PLUGINS[@]}"; do
        if plugin_enabled "$plugin"; then
            status_icon="●"
            status_color="${GREEN:-}"
        else
            status_icon="○"
            status_color="${GREY:-}"
        fi
        
        printf '  %s%s%s %-12s %s%s%s\n' \
            "$status_color" "$status_icon" "${NC:-}" \
            "$plugin" \
            "${GREY:-}" "${PLUGIN_DESCRIPTIONS[$plugin]}" "${NC:-}"
        
        # Details
        printf '      %sTyp:%s %-10s %sVersion:%s %s\n' \
            "${GREY:-}" "${NC:-}" "${PLUGIN_TYPES[$plugin]}" \
            "${GREY:-}" "${NC:-}" "${PLUGIN_VERSIONS[$plugin]}"
        
        # Commands
        local cmds="${PLUGIN_COMMANDS[$plugin]:-}"
        if [[ -n "$cmds" ]]; then
            printf '      %sBefehle:%s %s\n' "${GREY:-}" "${NC:-}" "$cmds"
        fi
        
        echo
    done
}

# Zeigt Details zu einem Plugin
show_plugin_info() {
    local name="$1"
    
    if ! plugin_exists "$name"; then
        err "Plugin '$name' nicht gefunden"
        return 1
    fi
    
    local enabled_text
    if plugin_enabled "$name"; then
        enabled_text="${GREEN:-}aktiviert${NC:-}"
    else
        enabled_text="${RED:-}deaktiviert${NC:-}"
    fi
    
    printf '\n  %s%s%s v%s\n' \
        "${BOLD:-}${CYAN:-}" "${PLUGIN_NAMES[$name]}" "${NC:-}" \
        "${PLUGIN_VERSIONS[$name]}"
    printf '  %s\n' "──────────────────────────────────────────────────"
    printf '  %s\n\n' "${PLUGIN_DESCRIPTIONS[$name]}"
    
    printf '  %sStatus:%s      %s\n' "${GREY:-}" "${NC:-}" "$enabled_text"
    printf '  %sTyp:%s         %s\n' "${GREY:-}" "${NC:-}" "${PLUGIN_TYPES[$name]}"
    printf '  %sPfad:%s        %s\n' "${GREY:-}" "${NC:-}" "${PLUGIN_PATHS[$name]}"
    
    local installer="${PLUGIN_INSTALLERS[$name]:-}"
    if [[ -n "$installer" ]]; then
        printf '  %sInstaller:%s   %s\n' "${GREY:-}" "${NC:-}" "$installer"
    fi
    
    local cmds="${PLUGIN_COMMANDS[$name]:-}"
    if [[ -n "$cmds" ]]; then
        printf '  %sBefehle:%s     %s\n' "${GREY:-}" "${NC:-}" "$cmds"
    fi
    
    local deps="${PLUGIN_DEPENDENCIES[$name]:-}"
    if [[ -n "$deps" ]]; then
        printf '  %sAbhängig.:%s   %s\n' "${GREY:-}" "${NC:-}" "$deps"
    fi
    
    echo
}

# Handler für 'SOT plugins' Befehle
handle_plugins_command() {
    local action="${1:-list}"
    shift || true
    
    case "$action" in
        list|ls)
            show_plugins_list
            ;;
        info|show)
            [[ $# -eq 0 ]] && { err "Plugin-Name erforderlich"; return 1; }
            show_plugin_info "$1"
            ;;
        enable)
            [[ $# -eq 0 ]] && { err "Plugin-Name erforderlich"; return 1; }
            enable_plugin "$1"
            ;;
        disable)
            [[ $# -eq 0 ]] && { err "Plugin-Name erforderlich"; return 1; }
            disable_plugin "$1"
            ;;
        install)
            [[ $# -eq 0 ]] && { err "Plugin-Name erforderlich"; return 1; }
            install_plugin "$@"
            ;;
        run|exec)
            [[ $# -lt 2 ]] && { err "Plugin und Befehl erforderlich"; return 1; }
            run_plugin_command "$@"
            ;;
        help|--help|-h)
            show_plugins_help
            ;;
        *)
            # Vielleicht ist es ein Plugin-Name?
            if plugin_exists "$action"; then
                if [[ $# -gt 0 ]]; then
                    run_plugin_command "$action" "$@"
                else
                    show_plugin_info "$action"
                fi
            else
                err "Unbekannte Aktion: $action"
                show_plugins_help
                return 1
            fi
            ;;
    esac
}

# Hilfe für Plugin-Befehle
show_plugins_help() {
    printf '\n  %sPlugin-Verwaltung%s\n' "${BOLD:-}" "${NC:-}"
    printf '  %s\n\n' "──────────────────────────────────────────────────"
    
    printf '  %sUsage:%s SOT plugins <action> [options]\n\n' "${GREY:-}" "${NC:-}"
    
    printf '  %sAktionen:%s\n' "${YELLOW:-}" "${NC:-}"
    printf '    %-20s %s\n' "list" "Alle Plugins anzeigen"
    printf '    %-20s %s\n' "info <name>" "Plugin-Details anzeigen"
    printf '    %-20s %s\n' "enable <name>" "Plugin aktivieren"
    printf '    %-20s %s\n' "disable <name>" "Plugin deaktivieren"
    printf '    %-20s %s\n' "install <name>" "Plugin installieren"
    printf '    %-20s %s\n' "run <name> <cmd>" "Plugin-Befehl ausführen"
    printf '    %-20s %s\n' "<name>" "Plugin-Info anzeigen"
    printf '    %-20s %s\n' "<name> <cmd>" "Plugin-Befehl ausführen"
    echo
    
    printf '  %sBeispiele:%s\n' "${YELLOW:-}" "${NC:-}"
    printf '    %s\n' "SOT plugins list"
    printf '    %s\n' "SOT plugins info ansible"
    printf '    %s\n' "SOT plugins ansible trigger site.yml"
    printf '    %s\n' "SOT plugins install docker"
    echo
}

# =============================================================================
# Initialisierung
# =============================================================================

# Auto-Discovery beim Laden (falls SOT_ROOT gesetzt)
if [[ -n "${SOT_ROOT:-}" || -n "${MODULES_DIR:-}" ]]; then
    discover_plugins
fi
