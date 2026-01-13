#!/usr/bin/env bash
# SOT Bootstrap Library: Task Runner
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
    [editCliFile]="Konfiguriere CLI"
    [createCliWrapperSbinLink]="Erstelle CLI-Symlink"
    [makeScriptExecutable]="Setze Ausführungsrechte"
    [writeConfigFile]="Schreibe Konfigurationsdatei"
    [installDependencies]="Installiere Dependencies"
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
# Progress Bar Utilities
# =============================================================================

# Draw a progress bar
# Arguments:
#   $1 - current step
#   $2 - total steps
draw_progress_bar() {
    local current=$1
    local total=$2
    local percentage=$((current * 100 / total))
    local filled=$((current * 40 / total))
    local empty=$((40 - filled))
    
    printf "  ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %d%%" "$percentage"
}

# =============================================================================
# Logging & Output
# =============================================================================

# Log file for all output when not in debug mode
BOOTSTRAP_LOG_FILE="/tmp/sot-bootstrap-$$.log"

# Silent task execution - redirect output to log
# Arguments:
#   $1 - Task function name
run_task_silent() {
    local task="$1"
    "$task" >> "$BOOTSTRAP_LOG_FILE" 2>&1
}

# Debug task execution - show all output
# Arguments:
#   $1 - Task function name
run_task_debug() {
    local task="$1"
    "$task"
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

# Run a single task with progress bar (non-debug mode)
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
    
    # Clear line and show progress bar
    printf "\r\033[K"
    draw_progress_bar "$current" "$total"
    printf " %s" "$label"
    
    # Run task silently
    if run_task_silent "$task"; then
        printf " ${GREEN:-}✓${NC:-}"
    else
        printf " ${RED:-}✗${NC:-}\n"
        # Bei kritischen Tasks abbrechen
        if is_critical_task "$task"; then
            printf "\n  ${RED:-}✗ Installation fehlgeschlagen${NC:-}\n"
            printf "  ${GREY:-}Log: $BOOTSTRAP_LOG_FILE${NC:-}\n\n"
            exit 1
        fi
    fi
}

# Run a single task in debug mode (verbose output)
# Arguments:
#   $1 - Task function name
#   $2 - Current task number
#   $3 - Total tasks
run_task_verbose() {
    local task="$1"
    local current="${2:-1}"
    local total="${3:-1}"
    local label
    label=$(get_task_label "$task")
    
    printf "\n  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "  ${GREEN}[%d/%d]${NC} ${BOLD}%s${NC}\n" "$current" "$total" "$label"
    printf "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
    
    # Run task with full output
    if run_task_debug "$task"; then
        printf "\n  ${GREEN}✓ Erfolgreich${NC}\n"
    else
        printf "\n  ${RED}✗ Fehlgeschlagen${NC}\n"
        if is_critical_task "$task"; then
            printf "\n  ${RED}✗ Installation abgebrochen${NC}\n\n"
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
    
    # Check if debug mode is enabled
    if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
        # Debug Mode: Verbose output with task details
        printf "\n"
        printf "  ${DIM}╔══════════════════════════════════════════════════════════════╗${NC}\n"
        printf "  ${DIM}║${NC}      ${GREEN}SOT Bootstrap${NC} - Installation (${YELLOW}Debug-Modus${NC})        ${DIM}║${NC}\n"
        printf "  ${DIM}╚══════════════════════════════════════════════════════════════╝${NC}\n"
        
        for task in "${tasks[@]}"; do
            ((++current))
            run_task_verbose "$task" "$current" "$total"
        done
        
        printf "\n  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    else
        # Normal Mode: Progress bar only
        printf "\n"
        printf "  ${DIM}╔══════════════════════════════════════════════════════════════╗${NC}\n"
        printf "  ${DIM}║${NC}          ${GREEN}SOT Bootstrap${NC} - Installation läuft...           ${DIM}║${NC}\n"
        printf "  ${DIM}╚══════════════════════════════════════════════════════════════╝${NC}\n"
        printf "\n"
        
        # Initialize log file
        echo "SOT Bootstrap Log - $(date)" > "$BOOTSTRAP_LOG_FILE"
        echo "========================================" >> "$BOOTSTRAP_LOG_FILE"
        
        for task in "${tasks[@]}"; do
            ((++current))
            run_task "$task" "$current" "$total"
        done
        
        # Final newline after progress bar
        printf "\n\n"
    fi
    
    # Zeitberechnung
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    # Footer
    printf "  ${DIM}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "  ${DIM}║${NC}  ${GREEN}✓ Installation erfolgreich abgeschlossen${NC}                 ${DIM}║${NC}\n"
    if [[ $minutes -gt 0 ]]; then
        printf "  ${DIM}║${NC}  Dauer: %d Minute(n) %d Sekunde(n)                         ${DIM}║${NC}\n" "$minutes" "$seconds"
    else
        printf "  ${DIM}║${NC}  Dauer: %d Sekunde(n)                                       ${DIM}║${NC}\n" "$seconds"
    fi
    
    # Show log location in non-debug mode
    if [[ "${DEBUG_MODE:-false}" != "true" ]]; then
        printf "  ${DIM}║${NC}  Log: ${DIM}$BOOTSTRAP_LOG_FILE${NC}\n"
    fi
    
    printf "  ${DIM}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    printf "\n"
}

# Run tasks without progress (deprecated, kept for compatibility)
# Arguments:
#   $@ - Array of task function names
run_tasks_sync() {
    DEBUG_MODE=true run_tasks "$@"
}
