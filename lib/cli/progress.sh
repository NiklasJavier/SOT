#!/usr/bin/env bash
# =============================================================================
# SOT Progress - Fortschrittsanzeigen und Spinner
# =============================================================================
#
# Features:
#   - Einfache Progress-Bars mit Prozentanzeige
#   - Multi-Step Progress für mehrstufige Operationen
#   - Spinner für unbestimmte Wartezeiten
#   - Task-Listen mit Status-Updates
#
# Verwendung:
#   source "$SOT_LIB_DIR/cli/progress.sh"
#   
#   # Einfache Progress-Bar
#   progress_bar 50 100 "Downloading..."
#   
#   # Multi-Step Progress
#   progress_start "Installing Module" 4
#   progress_step "Dependencies"
#   progress_step "Configuration"
#   progress_step "Verification"
#   progress_step "Cleanup"
#   progress_end
#
# =============================================================================

[[ -n "${_SOT_CLI_PROGRESS_LOADED:-}" ]] && return 0
_SOT_CLI_PROGRESS_LOADED=1

# =============================================================================
# Konfiguration
# =============================================================================

# Progress-Bar Zeichen
readonly PROGRESS_CHAR_FILLED="█"
readonly PROGRESS_CHAR_EMPTY="░"
readonly PROGRESS_WIDTH=30

# Spinner-Zeichen
readonly SPINNER_CHARS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPINNER_PID=""

# Multi-Step State
declare -g PROGRESS_TITLE=""
declare -g PROGRESS_TOTAL=0
declare -g PROGRESS_CURRENT=0
declare -g PROGRESS_START_TIME=0
declare -ga PROGRESS_STEPS=()

# =============================================================================
# Einfache Progress-Bar
# =============================================================================

# Zeigt eine Progress-Bar an
# Arguments:
#   $1 - Aktueller Wert
#   $2 - Maximum
#   $3 - Label (optional)
#   $4 - Show percentage (optional, default: true)
progress_bar() {
    local current="$1"
    local total="$2"
    local label="${3:-}"
    local show_percent="${4:-true}"
    
    # Prozent berechnen
    local percent=0
    if [[ "$total" -gt 0 ]]; then
        percent=$((current * 100 / total))
    fi
    
    # Anzahl gefüllter Zeichen
    local filled=$((percent * PROGRESS_WIDTH / 100))
    local empty=$((PROGRESS_WIDTH - filled))
    
    # Bar zusammenbauen
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="${PROGRESS_CHAR_FILLED}"
    done
    for ((i=0; i<empty; i++)); do
        bar+="${PROGRESS_CHAR_EMPTY}"
    done
    
    # Ausgabe
    if [[ "$show_percent" == "true" ]]; then
        printf "\r  ${GREEN:-}[%s]${NC:-} %3d%% %s" "$bar" "$percent" "$label"
    else
        printf "\r  ${GREEN:-}[%s]${NC:-} %s" "$bar" "$label"
    fi
}

# Schließt die Progress-Bar ab (neue Zeile)
progress_bar_done() {
    local label="${1:-Done}"
    printf "\r  ${GREEN:-}[%s]${NC:-} 100%% ${GREEN:-}✓${NC:-} %s\n" \
        "$(printf '%*s' "$PROGRESS_WIDTH" | tr ' ' "$PROGRESS_CHAR_FILLED")" \
        "$label"
}

# Progress-Bar mit Fehler beenden
progress_bar_fail() {
    local label="${1:-Failed}"
    printf "\r  ${RED:-}[%s]${NC:-} ${RED:-}✗${NC:-} %s\n" \
        "$(printf '%*s' "$PROGRESS_WIDTH" | tr ' ' "$PROGRESS_CHAR_EMPTY")" \
        "$label"
}

# =============================================================================
# Multi-Step Progress
# =============================================================================

# Startet einen Multi-Step Progress
# Arguments:
#   $1 - Titel der Operation
#   $2 - Anzahl der Schritte
progress_start() {
    local title="$1"
    local total="$2"
    
    PROGRESS_TITLE="$title"
    PROGRESS_TOTAL="$total"
    PROGRESS_CURRENT=0
    PROGRESS_START_TIME=$(date +%s)
    PROGRESS_STEPS=()
    
    # Header ausgeben
    printf "\n"
    printf "  ${BOLD:-}┌${NC:-} %s\n" "$title"
}

# Führt einen Schritt aus und zeigt Progress
# Arguments:
#   $1 - Schritt-Name
#   $2 - Status: "running" (default), "done", "skip", "fail"
progress_step() {
    local step_name="$1"
    local status="${2:-running}"
    
    case "$status" in
        running)
            ((++PROGRESS_CURRENT)) || true
            PROGRESS_STEPS+=("$step_name")
            
            # Progress-Bar für diesen Schritt
            local percent=$((PROGRESS_CURRENT * 100 / PROGRESS_TOTAL))
            local filled=$((percent * 20 / 100))
            local empty=$((20 - filled))
            
            local bar=""
            for ((i=0; i<filled; i++)); do bar+="${PROGRESS_CHAR_FILLED}"; done
            for ((i=0; i<empty; i++)); do bar+="${PROGRESS_CHAR_EMPTY}"; done
            
            printf "  ${BOLD:-}├${NC:-} ${GREEN:-}[%s]${NC:-} %3d%% %s" "$bar" "$percent" "$step_name"
            ;;
        done)
            printf "\r  ${BOLD:-}├${NC:-} ${GREEN:-}[%s]${NC:-} %3d%% ${GREEN:-}✓${NC:-} %s\n" \
                "$(printf '%*s' 20 | tr ' ' "$PROGRESS_CHAR_FILLED")" \
                "$((PROGRESS_CURRENT * 100 / PROGRESS_TOTAL))" \
                "$step_name"
            ;;
        skip)
            printf "\r  ${BOLD:-}├${NC:-} ${YELLOW:-}[%s]${NC:-} %3d%% ${YELLOW:-}⊘${NC:-} %s ${GREY:-}(übersprungen)${NC:-}\n" \
                "$(printf '%*s' 20 | tr ' ' "$PROGRESS_CHAR_EMPTY")" \
                "$((PROGRESS_CURRENT * 100 / PROGRESS_TOTAL))" \
                "$step_name"
            ;;
        fail)
            printf "\r  ${BOLD:-}├${NC:-} ${RED:-}[%s]${NC:-} %3d%% ${RED:-}✗${NC:-} %s ${RED:-}(fehlgeschlagen)${NC:-}\n" \
                "$(printf '%*s' 20 | tr ' ' "$PROGRESS_CHAR_EMPTY")" \
                "$((PROGRESS_CURRENT * 100 / PROGRESS_TOTAL))" \
                "$step_name"
            ;;
    esac
}

# Markiert aktuellen Schritt als erledigt
progress_step_done() {
    local step_name="${1:-${PROGRESS_STEPS[-1]:-}}"
    progress_step "$step_name" "done"
}

# Markiert aktuellen Schritt als übersprungen
progress_step_skip() {
    local step_name="${1:-${PROGRESS_STEPS[-1]:-}}"
    progress_step "$step_name" "skip"
}

# Markiert aktuellen Schritt als fehlgeschlagen
progress_step_fail() {
    local step_name="${1:-${PROGRESS_STEPS[-1]:-}}"
    progress_step "$step_name" "fail"
}

# Beendet den Multi-Step Progress
# Arguments:
#   $1 - Endstatus: "success" (default), "fail", "partial"
progress_end() {
    local status="${1:-success}"
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - PROGRESS_START_TIME))
    
    # Zeit formatieren
    local time_str
    if [[ "$duration" -lt 60 ]]; then
        time_str="${duration}s"
    else
        time_str="$((duration / 60))m $((duration % 60))s"
    fi
    
    case "$status" in
        success)
            printf "  ${BOLD:-}└${NC:-} ${GREEN:-}✓${NC:-} %s ${GREY:-}in %s${NC:-}\n\n" \
                "$PROGRESS_TITLE abgeschlossen" "$time_str"
            ;;
        fail)
            printf "  ${BOLD:-}└${NC:-} ${RED:-}✗${NC:-} %s ${GREY:-}nach %s${NC:-}\n\n" \
                "$PROGRESS_TITLE fehlgeschlagen" "$time_str"
            ;;
        partial)
            printf "  ${BOLD:-}└${NC:-} ${YELLOW:-}⚠${NC:-} %s ${GREY:-}in %s${NC:-}\n\n" \
                "$PROGRESS_TITLE teilweise abgeschlossen" "$time_str"
            ;;
    esac
    
    # State zurücksetzen
    PROGRESS_TITLE=""
    PROGRESS_TOTAL=0
    PROGRESS_CURRENT=0
    PROGRESS_STEPS=()
}

# =============================================================================
# Spinner für unbestimmte Wartezeiten
# =============================================================================

# Startet einen Spinner im Hintergrund
# Arguments:
#   $1 - Nachricht
spinner_start() {
    local message="$1"
    
    # Falls bereits ein Spinner läuft, stoppen
    spinner_stop 2>/dev/null || true
    
    # Spinner im Hintergrund starten
    (
        local i=0
        while true; do
            printf "\r  ${CYAN:-}%s${NC:-} %s" "${SPINNER_CHARS[$i]}" "$message"
            i=$(( (i + 1) % ${#SPINNER_CHARS[@]} ))
            sleep 0.1
        done
    ) &
    SPINNER_PID=$!
    
    # Trap für Cleanup
    trap 'spinner_stop 2>/dev/null' EXIT
}

# Stoppt den Spinner
# Arguments:
#   $1 - Endstatus: "success" (default), "fail"
#   $2 - Abschluss-Nachricht (optional)
spinner_stop() {
    local status="${1:-success}"
    local message="${2:-}"
    
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
    fi
    
    # Zeile löschen
    printf "\r%*s\r" 80 ""
    
    if [[ -n "$message" ]]; then
        case "$status" in
            success)
                printf "  ${GREEN:-}✓${NC:-} %s\n" "$message"
                ;;
            fail)
                printf "  ${RED:-}✗${NC:-} %s\n" "$message"
                ;;
        esac
    fi
}

# =============================================================================
# Task-Liste mit Status
# =============================================================================

# Zeigt eine Task-Liste mit Live-Updates
# Arguments:
#   $@ - Array von Task-Namen
declare -ga TASK_LIST=()
declare -ga TASK_STATUS=()

task_list_init() {
    TASK_LIST=("$@")
    TASK_STATUS=()
    
    # Initial alle als pending
    for task in "${TASK_LIST[@]}"; do
        TASK_STATUS+=("pending")
    done
    
    # Liste anzeigen
    printf "\n"
    local i=0
    for task in "${TASK_LIST[@]}"; do
        printf "  ${GREY:-}○${NC:-} %s\n" "$task"
        ((++i)) || true
    done
}

# Aktualisiert den Status einer Task
# Arguments:
#   $1 - Task-Index (0-basiert)
#   $2 - Status: "running", "done", "fail", "skip"
task_update() {
    local index="$1"
    local status="$2"
    
    TASK_STATUS[$index]="$status"
    
    # Cursor nach oben bewegen
    local total=${#TASK_LIST[@]}
    local lines_up=$((total - index))
    printf "\033[%dA" "$lines_up"
    
    # Status-Symbol
    local symbol
    case "$status" in
        running) symbol="${CYAN:-}●${NC:-}" ;;
        done)    symbol="${GREEN:-}✓${NC:-}" ;;
        fail)    symbol="${RED:-}✗${NC:-}" ;;
        skip)    symbol="${YELLOW:-}⊘${NC:-}" ;;
        *)       symbol="${GREY:-}○${NC:-}" ;;
    esac
    
    # Zeile aktualisieren
    printf "\r  %s %s\n" "$symbol" "${TASK_LIST[$index]}"
    
    # Cursor zurück nach unten
    if [[ "$lines_up" -gt 1 ]]; then
        printf "\033[%dB" "$((lines_up - 1))"
    fi
}

# Markiert eine Task als laufend
task_running() {
    task_update "$1" "running"
}

# Markiert eine Task als erledigt
task_done() {
    task_update "$1" "done"
}

# Markiert eine Task als fehlgeschlagen
task_fail() {
    task_update "$1" "fail"
}

# Markiert eine Task als übersprungen
task_skip() {
    task_update "$1" "skip"
}

# =============================================================================
# Hilfsfunktionen
# =============================================================================

# Simuliert einen Fortschritt (für Demos/Tests)
# Arguments:
#   $1 - Dauer in Sekunden
#   $2 - Label
progress_simulate() {
    local duration="${1:-3}"
    local label="${2:-Processing...}"
    local steps=$((duration * 10))
    
    for ((i=0; i<=steps; i++)); do
        progress_bar "$i" "$steps" "$label"
        sleep 0.1
    done
    progress_bar_done "$label"
}

# Wrapper für Befehle mit Progress-Anzeige
# Arguments:
#   $1 - Label
#   $@ - Befehl und Argumente
run_with_spinner() {
    local label="$1"
    shift
    
    spinner_start "$label"
    
    if "$@" >/dev/null 2>&1; then
        spinner_stop "success" "$label"
        return 0
    else
        spinner_stop "fail" "$label"
        return 1
    fi
}

# Wrapper für Befehle mit Progress-Bar (wenn Fortschritt messbar)
# Arguments:
#   $1 - Label
#   $2 - Befehl der Zeilenzahl ausgibt
#   $@ - Haupt-Befehl
run_with_progress() {
    local label="$1"
    local count_cmd="$2"
    shift 2
    
    local total
    total=$(eval "$count_cmd" 2>/dev/null || echo "100")
    local current=0
    
    while IFS= read -r line; do
        ((++current)) || true
        progress_bar "$current" "$total" "$label"
    done < <("$@" 2>&1)
    
    progress_bar_done "$label"
}
