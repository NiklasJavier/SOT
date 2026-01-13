#!/usr/bin/env bash
# SOT Setup Library: Task Runner
# Provides utilities for running setup tasks with progress indication
#
# Usage: source "$SETUP_LIB_DIR/runner.sh"
#        run_tasks "${TASK_LIST[@]}"

# Prevent multiple sourcing
[[ -n "${_SOT_SETUP_RUNNER_LOADED:-}" ]] && return 0
_SOT_SETUP_RUNNER_LOADED=1

# =============================================================================
# Task-Name zu lesbarem Label Mapping
# =============================================================================

declare -gA TASK_LABELS=(
    [checkSettingsDirExist]="Prüfe Verzeichnisstruktur"
    [startOverview]="Zeige Konfigurationsübersicht"
    [checkRootPermissions]="Prüfe Root-Berechtigungen"
    [copyAndSetTheRepository]="Klone Repository"
    [settingsEnvironmentFolder]="Erstelle Einstellungsordner"
    [editCliWrapperFile]="Konfiguriere CLI-Wrapper"
    [createCliWrapperSbinLink]="Erstelle CLI-Symlink"
    [makeScriptExecutable]="Setze Ausführungsrechte"
    [writeConfigFile]="Schreibe Konfigurationsdatei"
    [installAvailableTools]="Installiere Tools"
    [initalScriptOverview]="Zeige Abschlussübersicht"
)

# Holt das lesbare Label für einen Task
# Arguments:
#   $1 - Task-Name
get_task_label() {
    local task="$1"
    echo "${TASK_LABELS[$task]:-$task}"
}

# =============================================================================
# Progress Runner
# =============================================================================

# Liste von Tasks die bei Fehler das Setup abbrechen sollen
declare -ga CRITICAL_TASKS=(
    "checkSettingsDirExist"
    "checkRootPermissions"
    "copyAndSetTheRepository"
)

# Prüft ob ein Task kritisch ist
is_critical_task() {
    local task="$1"
    for critical in "${CRITICAL_TASKS[@]}"; do
        [[ "$task" == "$critical" ]] && return 0
    done
    return 1
}

# Run a single task - DIRECT execution without output redirection
# Arguments:
#   $1 - Task function name
#   $2 - Current task number
#   $3 - Total tasks
run_task() {
    local task="$1"
    local current="${2:-1}"
    local total="${3:-1}"
    local label
    label=$(get_task_label "$task")
    
    # Zeige Task-Info direkt
    printf "  [%d/%d] %s... " "$current" "$total" "$label"
    
    # Task DIREKT ausführen - keine Umleitung, keine Subshell
    if "$task"; then
        printf "${GREEN:-}✓${NC:-}\n"
    else
        printf "${RED:-}✗${NC:-}\n"
        # Bei kritischen Tasks abbrechen
        if is_critical_task "$task"; then
            printf "\n  ${RED:-}Setup abgebrochen.${NC:-}\n\n"
            exit 1
        fi
    fi
}

# Run multiple tasks in sequence
# Arguments:
#   $@ - Array of task function names
run_tasks() {
    local tasks=("$@")
    local total=${#tasks[@]}
    local current=0
    local start_time
    start_time=$(date +%s)
    
    # Header
    printf "\n"
    printf "  ╔══════════════════════════════════════════════════════════════╗\n"
    printf "  ║          ${GREEN:-}SOT Setup${NC:-} - Installation wird durchgeführt          ║\n"
    printf "  ╚══════════════════════════════════════════════════════════════╝\n"
    printf "\n"
    
    for task in "${tasks[@]}"; do
        ((++current))
        run_task "$task" "$current" "$total"
    done
    
    # Zeitberechnung
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    # Footer
    printf "\n"
    printf "  ╔══════════════════════════════════════════════════════════════╗\n"
    printf "  ║  ${GREEN:-}✓ Installation abgeschlossen${NC:-}                                 ║\n"
    if [[ $minutes -gt 0 ]]; then
        printf "  ║  Dauer: %d Minute(n) %d Sekunde(n)                              ║\n" "$minutes" "$seconds"
    else
        printf "  ║  Dauer: %d Sekunde(n)                                          ║\n" "$seconds"
    fi
    printf "  ╚══════════════════════════════════════════════════════════════╝\n"
    printf "\n"
}

# Run tasks without progress (for debugging)
# Arguments:
#   $@ - Array of task function names
run_tasks_sync() {
    local tasks=("$@")
    
    for task in "${tasks[@]}"; do
        local label
        label=$(get_task_label "$task")
        echo -e "\n${GREY}======= ${GREEN}$label${GREY} =======${NC}"
        "$task"
    done
    
    echo -e "\n${GREEN}Alle Aufgaben abgeschlossen!${NC}"
}
