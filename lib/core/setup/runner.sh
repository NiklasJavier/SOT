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
    [cloneOrUpdateAAT]="Setup AAT-Integration"
    [cloneOrUpdateTID]="Setup TID-Integration"
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

# Run a single task with progress indication
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
    
    # Zeige Progress-Bar mit aktuellem Task
    progress_bar "$current" "$total" "$label"
    
    # Task ausführen (Ausgabe in temp Datei für Fehlerbehandlung)
    local output_file
    output_file=$(mktemp)
    
    if "$task" > "$output_file" 2>&1; then
        # Erfolg
        progress_bar "$current" "$total" "${GREEN:-}✓${NC:-} $label"
        printf "\n"
    else
        # Fehler
        progress_bar "$current" "$total" "${RED:-}✗${NC:-} $label"
        printf "\n"
        # Zeige Fehlerausgabe
        if [[ -s "$output_file" ]]; then
            printf "    ${RED:-}Fehler:${NC:-}\n"
            sed 's/^/    /' "$output_file"
        fi
    fi
    
    rm -f "$output_file"
}

# Run multiple tasks in sequence with overall progress
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
    printf "  ${BOLD:-}╔══════════════════════════════════════════════════════════════╗${NC:-}\n"
    printf "  ${BOLD:-}║${NC:-}          ${GREEN:-}SOT Setup${NC:-} - Installation wird durchgeführt          ${BOLD:-}║${NC:-}\n"
    printf "  ${BOLD:-}╚══════════════════════════════════════════════════════════════╝${NC:-}\n"
    printf "\n"
    printf "  ${GREY:-}$total Aufgaben werden ausgeführt...${NC:-}\n\n"
    
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
    printf "  ${BOLD:-}╔══════════════════════════════════════════════════════════════╗${NC:-}\n"
    printf "  ${BOLD:-}║${NC:-}  ${GREEN:-}✓ Installation abgeschlossen${NC:-}                                 ${BOLD:-}║${NC:-}\n"
    if [[ $minutes -gt 0 ]]; then
        printf "  ${BOLD:-}║${NC:-}  ${GREY:-}Dauer: %d Minute(n) %d Sekunde(n)${NC:-}                              ${BOLD:-}║${NC:-}\n" "$minutes" "$seconds"
    else
        printf "  ${BOLD:-}║${NC:-}  ${GREY:-}Dauer: %d Sekunde(n)${NC:-}                                          ${BOLD:-}║${NC:-}\n" "$seconds"
    fi
    printf "  ${BOLD:-}╚══════════════════════════════════════════════════════════════╝${NC:-}\n"
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
