#!/bin/bash
# SOT Setup Library: Task Runner
# Provides utilities for running setup tasks with progress indication
#
# Usage: source "$SETUP_LIB_DIR/runner.sh"
#        run_tasks "${TASK_LIST[@]}"

# Prevent multiple sourcing
[[ -n "${_SOT_SETUP_RUNNER_LOADED:-}" ]] && return 0
_SOT_SETUP_RUNNER_LOADED=1

# Show a loading spinner while a background process runs
# Arguments:
#   $1 - PID of the background process
_show_loading() {
    local pid=$1
    local delay=0.01
    local spinstr="|/-\\"

    while kill -0 "$pid" 2>/dev/null; do
        for ((i = 0; i < 4; i++)); do
            printf "\r ${PINK}[%c]${GREY} " "${spinstr:i:1}"
            sleep $delay
        done
    done
    printf "\r    \r"
}

# Run a single task with progress indication
# Arguments:
#   $1 - Task function name
run_task() {
    local task="$1"
    echo -e "\n${GREY}======= ${GREEN}Running: ${PINK}[$task] ${GREY}=======${NC}"
    
    "$task" &
    local pid=$!
    _show_loading $pid
    wait $pid
}

# Run multiple tasks in sequence
# Arguments:
#   $@ - Array of task function names
run_tasks() {
    local tasks=("$@")
    
    for task in "${tasks[@]}"; do
        run_task "$task"
    done
    
    echo -e "${GREEN}All tasks completed!${NC}"
}

# Run tasks without background/spinner (for debugging)
# Arguments:
#   $@ - Array of task function names
run_tasks_sync() {
    local tasks=("$@")
    
    for task in "${tasks[@]}"; do
        echo -e "\n${GREY}======= ${GREEN}Running: ${PINK}[$task] ${GREY}=======${NC}"
        "$task"
    done
    
    echo -e "${GREEN}All tasks completed!${NC}"
}
