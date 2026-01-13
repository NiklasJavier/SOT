#!/usr/bin/env bash
# =============================================================================
# SOT Progress Demo - Zeigt alle Progress-Funktionen
# =============================================================================
# @cmd: demo-progress
# @category: info
# @description: Demo der Progress-Bar Funktionen
# @usage: SOT demo-progress
# @example: SOT demo-progress
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Libraries laden
source "$ROOT_DIR/lib/init.sh"
source "$ROOT_DIR/lib/cli/progress.sh"

# =============================================================================
# Demo-Funktionen
# =============================================================================

demo_simple_progress() {
    echo ""
    echo "  ${BOLD:-}1. Einfache Progress-Bar${NC:-}"
    echo "  ─────────────────────────────────"
    
    for i in {0..100..5}; do
        progress_bar "$i" 100 "Downloading package..."
        sleep 0.05
    done
    progress_bar_done "Package downloaded"
    
    sleep 0.5
}

demo_multi_step() {
    echo ""
    echo "  ${BOLD:-}2. Multi-Step Progress${NC:-}"
    echo "  ─────────────────────────────────"
    
    progress_start "Installing Ansible Module" 5
    
    progress_step "Checking dependencies"
    sleep 0.8
    progress_step_done "Checking dependencies"
    
    progress_step "Downloading packages"
    sleep 1.0
    progress_step_done "Downloading packages"
    
    progress_step "Installing packages"
    sleep 0.6
    progress_step_done "Installing packages"
    
    progress_step "Configuring module"
    sleep 0.5
    progress_step_done "Configuring module"
    
    progress_step "Verifying installation"
    sleep 0.4
    progress_step_done "Verifying installation"
    
    progress_end "success"
    
    sleep 0.5
}

demo_multi_step_partial() {
    echo ""
    echo "  ${BOLD:-}3. Multi-Step mit Skip/Fail${NC:-}"
    echo "  ─────────────────────────────────"
    
    progress_start "Updating System" 4
    
    progress_step "Fetching updates"
    sleep 0.6
    progress_step_done "Fetching updates"
    
    progress_step "Installing security patches"
    sleep 0.8
    progress_step_done "Installing security patches"
    
    progress_step "Upgrading kernel"
    sleep 0.5
    progress_step_skip "Upgrading kernel"
    
    progress_step "Cleaning cache"
    sleep 0.4
    progress_step_done "Cleaning cache"
    
    progress_end "partial"
    
    sleep 0.5
}

demo_spinner() {
    echo ""
    echo "  ${BOLD:-}4. Spinner für unbestimmte Wartezeit${NC:-}"
    echo "  ─────────────────────────────────"
    
    spinner_start "Connecting to server..."
    sleep 2
    spinner_stop "success" "Connected to server"
    
    spinner_start "Synchronizing data..."
    sleep 1.5
    spinner_stop "success" "Data synchronized"
    
    sleep 0.5
}

demo_task_list() {
    echo ""
    echo "  ${BOLD:-}5. Task-Liste mit Live-Updates${NC:-}"
    echo "  ─────────────────────────────────"
    
    task_list_init \
        "Initialize environment" \
        "Download dependencies" \
        "Build project" \
        "Run tests" \
        "Deploy to staging"
    
    sleep 0.3
    task_running 0
    sleep 0.8
    task_done 0
    
    task_running 1
    sleep 1.0
    task_done 1
    
    task_running 2
    sleep 0.7
    task_done 2
    
    task_running 3
    sleep 0.5
    task_done 3
    
    task_running 4
    sleep 0.6
    task_done 4
    
    echo ""
    sleep 0.5
}

demo_combined() {
    echo ""
    echo "  ${BOLD:-}6. Kombiniertes Beispiel (realistische Installation)${NC:-}"
    echo "  ─────────────────────────────────"
    
    progress_start "Docker Module Installation" 4
    
    # Step 1: Dependencies
    progress_step "Installing dependencies"
    for i in {0..100..10}; do
        printf "\r  ${BOLD:-}├${NC:-} ${GREEN:-}[" 
        local filled=$((i * 20 / 100))
        for ((j=0; j<filled; j++)); do printf "█"; done
        for ((j=filled; j<20; j++)); do printf "░"; done
        printf "]${NC:-} %3d%% Installing dependencies" "$i"
        sleep 0.05
    done
    progress_step_done "Installing dependencies"
    
    # Step 2: Download
    progress_step "Downloading Docker CE"
    for i in {0..100..5}; do
        printf "\r  ${BOLD:-}├${NC:-} ${GREEN:-}["
        local filled=$((i * 20 / 100))
        for ((j=0; j<filled; j++)); do printf "█"; done
        for ((j=filled; j<20; j++)); do printf "░"; done
        printf "]${NC:-} %3d%% Downloading Docker CE" "$i"
        sleep 0.03
    done
    progress_step_done "Downloading Docker CE"
    
    # Step 3: Configure
    progress_step "Configuring Docker"
    sleep 0.8
    progress_step_done "Configuring Docker"
    
    # Step 4: Verify
    progress_step "Verifying installation"
    sleep 0.5
    progress_step_done "Verifying installation"
    
    progress_end "success"
}

# =============================================================================
# Hauptprogramm
# =============================================================================

main() {
    clear
    printf "\n"
    printf "  ${CYAN:-}╔═══════════════════════════════════════════════════════════╗${NC:-}\n"
    printf "  ${CYAN:-}║${NC:-}        ${BOLD:-}SOT Progress Demo${NC:-}                               ${CYAN:-}║${NC:-}\n"
    printf "  ${CYAN:-}║${NC:-}        Fortschrittsanzeigen für bessere UX              ${CYAN:-}║${NC:-}\n"
    printf "  ${CYAN:-}╚═══════════════════════════════════════════════════════════╝${NC:-}\n"
    
    demo_simple_progress
    demo_multi_step
    demo_multi_step_partial
    demo_spinner
    demo_task_list
    demo_combined
    
    printf "\n"
    printf "  ${GREEN:-}✓${NC:-} Demo abgeschlossen!\n"
    printf "\n"
    printf "  ${GREY:-}Verwendung in eigenen Skripten:${NC:-}\n"
    printf "    ${CYAN:-}source \"\$SOT_ROOT/lib/cli/progress.sh\"${NC:-}\n"
    printf "\n"
    printf "  ${GREY:-}Verfügbare Funktionen:${NC:-}\n"
    printf "    • progress_bar <current> <total> <label>\n"
    printf "    • progress_start/step/end für Multi-Step\n"
    printf "    • spinner_start/stop für Wartezeiten\n"
    printf "    • task_list_init + task_done/fail/skip\n"
    printf "\n"
}

main "$@"
