#!/usr/bin/env bash
# =============================================================================
# SOT Extensions Manager
# =============================================================================
# Verwaltet externe Integrationen wie AAT, TID oder benutzerdefinierte Extensions.
# Extensions werden über die Konfigurationsdatei definiert und sind optional.
#
# Konfigurationsformat (default_config.yml):
#   <name>_enabled: "true"
#   <name>_repo_url: "https://github.com/..."
#   <name>_dir: "/opt/<NAME>"
#   <name>_branch: "main"
#   <name>_type: "ansible|terraform|script"
#   <name>_runner: "runner.sh"
#   <name>_description: "Beschreibung"
#
# Usage:
#   source "$SOT_ROOT/lib/extensions/manager.sh"
#   extension_list           # Alle Extensions auflisten
#   extension_sync "aat"     # Extension synchronisieren
#   extension_is_enabled "tid"  # Prüfen ob aktiviert
# =============================================================================

[[ -n "${_SOT_EXTENSIONS_MANAGER_LOADED:-}" ]] && return 0
_SOT_EXTENSIONS_MANAGER_LOADED=1

# =============================================================================
# Bekannte Extension-Namen (werden aus Config geladen)
# =============================================================================
declare -ga KNOWN_EXTENSIONS=("aat" "tid")

# =============================================================================
# Extension-Hilfsfunktionen
# =============================================================================

# Prüft ob eine Extension aktiviert ist
# Arguments: $1 - Extension-Name (lowercase)
# Returns: 0 wenn aktiviert, 1 wenn nicht
extension_is_enabled() {
    local name="$1"
    local var_name="${name}_enabled"
    local value="${!var_name:-false}"
    
    [[ "$value" == "true" ]]
}

# Holt einen Extension-Konfigurations wert
# Arguments: $1 - Extension-Name, $2 - Eigenschaft (repo_url, dir, branch, etc.)
# Returns: Wert oder leer
extension_get() {
    local name="$1"
    local prop="$2"
    local var_name="${name}_${prop}"
    
    # Versuche lowercase und uppercase Varianten
    local value="${!var_name:-}"
    if [[ -z "$value" ]]; then
        var_name="${name^^}_${prop^^}"  # AAT_DIR
        value="${!var_name:-}"
    fi
    
    echo "$value"
}

# Listet alle konfigurierten Extensions auf
# Returns: Array von Extension-Namen
extension_list() {
    local extensions=()
    
    for ext in "${KNOWN_EXTENSIONS[@]}"; do
        if [[ -n "$(extension_get "$ext" "repo_url")" ]]; then
            extensions+=("$ext")
        fi
    done
    
    # Dynamisch weitere Extensions aus Environment finden
    # (Variablen die auf _enabled enden)
    while IFS='=' read -r name _; do
        if [[ "$name" =~ ^([a-z]+)_enabled$ ]]; then
            local ext_name="${BASH_REMATCH[1]}"
            if [[ ! " ${extensions[*]} " =~ " ${ext_name} " ]]; then
                extensions+=("$ext_name")
            fi
        fi
    done < <(compgen -v | grep -E '^[a-z]+_enabled$' | while read v; do echo "$v=${!v}"; done 2>/dev/null || true)
    
    printf '%s\n' "${extensions[@]}"
}

# Listet alle aktivierten Extensions auf
extension_list_enabled() {
    local ext
    while read -r ext; do
        if extension_is_enabled "$ext"; then
            echo "$ext"
        fi
    done < <(extension_list)
}

# Synchronisiert eine Extension (Clone oder Pull)
# Arguments: $1 - Extension-Name
# Returns: 0 bei Erfolg, 1 bei Fehler
extension_sync() {
    local name="$1"
    local repo_url branch dir
    
    repo_url="$(extension_get "$name" "repo_url")"
    branch="$(extension_get "$name" "branch")"
    dir="$(extension_get "$name" "dir")"
    
    branch="${branch:-main}"
    
    if [[ -z "$repo_url" ]]; then
        echo "  ${RED:-}✗${NC:-} Extension '$name': Keine Repository-URL konfiguriert" >&2
        return 1
    fi
    
    if [[ -z "$dir" ]]; then
        echo "  ${RED:-}✗${NC:-} Extension '$name': Kein Zielverzeichnis konfiguriert" >&2
        return 1
    fi
    
    if ! command -v git &>/dev/null; then
        echo "  ${RED:-}✗${NC:-} Git nicht installiert" >&2
        return 1
    fi
    
    if [[ -d "$dir/.git" ]]; then
        # Update
        echo "  ${GREY:-}├──${NC:-} Aktualisiere ${YELLOW:-}$name${NC:-}..."
        if sudo git -C "$dir" fetch --all --quiet && sudo git -C "$dir" pull --quiet; then
            echo "  ${GREEN:-}✓${NC:-} $name aktualisiert"
            return 0
        else
            echo "  ${YELLOW:-}!${NC:-} $name: Pull fehlgeschlagen (fortfahren...)"
            return 0
        fi
    else
        # Clone
        echo "  ${GREY:-}├──${NC:-} Klone ${YELLOW:-}$name${NC:-} nach $dir..."
        sudo mkdir -p "$dir"
        if sudo git clone -b "$branch" --single-branch --quiet "$repo_url" "$dir"; then
            echo "  ${GREEN:-}✓${NC:-} $name geklont"
            return 0
        else
            echo "  ${RED:-}✗${NC:-} $name: Clone fehlgeschlagen"
            return 1
        fi
    fi
}

# Synchronisiert alle aktivierten Extensions
# Returns: Anzahl fehlgeschlagener Syncs
extension_sync_all() {
    local failed=0
    local ext
    local enabled_count=0
    
    # Zähle aktivierte Extensions
    while read -r ext; do
        ((++enabled_count))
    done < <(extension_list_enabled)
    
    if [[ "$enabled_count" -eq 0 ]]; then
        echo "  ${GREY:-}Keine Extensions aktiviert${NC:-}"
        return 0
    fi
    
    echo ""
    echo "  ${BOLD:-}┌── Extensions ($enabled_count)${NC:-}"
    
    while read -r ext; do
        if ! extension_sync "$ext"; then
            ((++failed))
        fi
    done < <(extension_list_enabled)
    
    echo "  ${BOLD:-}└── Fertig${NC:-}"
    echo ""
    
    return "$failed"
}

# Gibt Extension-Info aus
# Arguments: $1 - Extension-Name
extension_info() {
    local name="$1"
    local enabled repo_url dir branch type description
    
    enabled="$(extension_is_enabled "$name" && echo "true" || echo "false")"
    repo_url="$(extension_get "$name" "repo_url")"
    dir="$(extension_get "$name" "dir")"
    branch="$(extension_get "$name" "branch")"
    type="$(extension_get "$name" "type")"
    description="$(extension_get "$name" "description")"
    
    echo "Extension: ${name^^}"
    echo "  Aktiviert:    $enabled"
    echo "  Beschreibung: ${description:-n/a}"
    echo "  Typ:          ${type:-n/a}"
    echo "  Repository:   ${repo_url:-n/a}"
    echo "  Verzeichnis:  ${dir:-n/a}"
    echo "  Branch:       ${branch:-main}"
}

# =============================================================================
# Extension Runner Integration
# =============================================================================

# Führt den Runner einer Extension aus
# Arguments: $1 - Extension-Name, $2... - Runner-Argumente
extension_run() {
    local name="$1"
    shift
    
    local dir runner
    dir="$(extension_get "$name" "dir")"
    runner="$(extension_get "$name" "runner")"
    
    runner="${runner:-runner.sh}"
    
    if [[ ! -d "$dir" ]]; then
        echo "  ${RED:-}✗${NC:-} Extension '$name' nicht installiert: $dir" >&2
        return 1
    fi
    
    local runner_path="$dir/$runner"
    if [[ ! -f "$runner_path" ]]; then
        echo "  ${RED:-}✗${NC:-} Runner nicht gefunden: $runner_path" >&2
        return 1
    fi
    
    bash "$runner_path" "$@"
}
