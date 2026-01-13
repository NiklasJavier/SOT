#!/usr/bin/env bash
# SOT Setup Library: Argument Parser
# Handles CLI argument parsing for setup_sot.sh
#
# Usage: source "$SETUP_LIB_DIR/args_parser.sh"
#        parse_setup_args "$@"

# Prevent multiple sourcing
[[ -n "${_SOT_SETUP_ARGS_LOADED:-}" ]] && return 0
_SOT_SETUP_ARGS_LOADED=1

# Parse early arguments that need to be processed before other flags
# Arguments: "$@" - All command line arguments
# Sets: DEFAULT_CONFIG_FILE, DEFAULT_BRANCH_HINT
parse_early_args() {
    local args=("$@")
    
    for ((i = 0; i < ${#args[@]}; i++)); do
        case "${args[$i]}" in
            -config)
                local next_index=$((i + 1))
                if (( next_index < ${#args[@]} )) && [[ -n "${args[$next_index]}" && "${args[$next_index]}" != -* ]]; then
                    DEFAULT_CONFIG_FILE="${args[$next_index]}"
                else
                    err "No configuration file specified with -config."
                    exit 1
                fi
                ;;
            -branch)
                local next_index=$((i + 1))
                if (( next_index < ${#args[@]} )) && [[ -n "${args[$next_index]}" && "${args[$next_index]}" != -* ]]; then
                    DEFAULT_BRANCH_HINT="${args[$next_index]}"
                fi
                ;;
        esac
    done
}

# Parse all setup arguments
# Arguments: "$@" - All command line arguments
# Sets: Various configuration variables
parse_setup_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -branch)
                shift
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    err "No branch specified with -branch."
                    exit 1
                fi
                USE_DEFAULTS=true
                BRANCH="$1"
                DEFAULT_BRANCH_HINT="$1"
                ;;
            -full)
                shift
                if [[ "$1" == "true" || "$1" == "false" ]]; then
                    FULL="$1"
                else
                    err "Invalid value for FULL. Please use 'true' or 'false'."
                    exit 1
                fi
                ;;
            -systemname)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    SYSTEM_NAME="$1"
                else
                    err "No systemname specified with -systemname."
                    exit 1
                fi
                ;;
            -username)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    USERNAME="$1"
                else
                    err "No username specified with -username."
                    exit 1
                fi
                ;;
            -key)
                shift
                SSH_KEY_FUNCTION_ENABLED=true
                if [[ -n "$1" && "$1" != -* ]]; then
                    SSH_KEY_PUBLIC="$1"
                else
                    SSH_KEY_FUNCTION_ENABLED=false
                    SSH_KEY_PUBLIC=""
                fi
                ;;
            -port)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    SSH_PORT="$1"
                else
                    err "No port specified with -port."
                    exit 1
                fi
                ;;
            -tools)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    TOOLS+=" $1 "
                else
                    err "No tools specified with -tools."
                    exit 1
                fi
                ;;
            -aat_url)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    AAT_REPO_URL="$1"
                else
                    err "No AAT repo URL specified with -aat_url."
                    exit 1
                fi
                ;;
            -aat_dir)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    AAT_DIR="$1"
                else
                    err "No AAT directory specified with -aat_dir."
                    exit 1
                fi
                ;;
            -aat_enabled)
                shift
                if [[ "$1" == "true" || "$1" == "false" ]]; then
                    AAT_ENABLED="$1"
                else
                    err "Invalid value for aat_enabled. Please use 'true' or 'false'."
                    exit 1
                fi
                ;;
            -aat_branch)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    AAT_BRANCH="$1"
                else
                    err "No branch specified with -aat_branch."
                    exit 1
                fi
                ;;
            -tid_url)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    TID_REPO_URL="$1"
                else
                    err "No TID repo URL specified with -tid_url."
                    exit 1
                fi
                ;;
            -tid_dir)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    TID_DIR="$1"
                else
                    err "No TID directory specified with -tid_dir."
                    exit 1
                fi
                ;;
            -tid_enabled)
                shift
                if [[ "$1" == "true" || "$1" == "false" ]]; then
                    TID_ENABLED="$1"
                else
                    err "Invalid value for tid_enabled. Please use 'true' or 'false'."
                    exit 1
                fi
                ;;
            -tid_branch)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    TID_BRANCH="$1"
                else
                    err "No branch specified with -tid_branch."
                    exit 1
                fi
                ;;
            -local_ansible_enabled)
                shift
                if [[ "$1" == "true" || "$1" == "false" ]]; then
                    ANSIBLE_LOCAL_ENABLED="$1"
                else
                    err "Invalid value for local_ansible_enabled. Please use 'true' or 'false'."
                    exit 1
                fi
                ;;
            -local_ansible_priority)
                shift
                if [[ "$1" == "true" || "$1" == "false" ]]; then
                    ANSIBLE_LOCAL_PRIORITY="$1"
                else
                    err "Invalid value for local_ansible_priority. Please use 'true' or 'false'."
                    exit 1
                fi
                ;;
            -local_ansible_dir)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    ANSIBLE_LOCAL_DIR="$1"
                else
                    err "No directory specified with -local_ansible_dir."
                    exit 1
                fi
                ;;
            -overrides_dir)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    OVERRIDES_DIR="$1"
                else
                    err "No directory specified with -overrides_dir."
                    exit 1
                fi
                ;;
            -runner_enabled)
                shift
                if [[ "$1" == "true" || "$1" == "false" ]]; then
                    RUNNER_ENABLED="$1"
                else
                    err "Invalid value for runner_enabled. Please use 'true' or 'false'."
                    exit 1
                fi
                ;;
            -runner_mode)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    RUNNER_DEFAULT_MODE="$1"
                else
                    err "No mode specified with -runner_mode."
                    exit 1
                fi
                ;;
            -runner_sync)
                shift
                if [[ "$1" == "true" || "$1" == "false" ]]; then
                    RUNNER_SYNC_BEFORE_RUN="$1"
                else
                    err "Invalid value for -runner_sync. Use 'true' or 'false'."
                    exit 1
                fi
                ;;
            -runner_work_dir)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    RUNNER_WORK_DIR="$1"
                else
                    err "No directory specified with -runner_work_dir."
                    exit 1
                fi
                ;;
            -runner_log_dir)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    RUNNER_LOG_DIR="$1"
                else
                    err "No directory specified with -runner_log_dir."
                    exit 1
                fi
                ;;
            -runner_inventory)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    RUNNER_DEFAULT_INVENTORY="$1"
                else
                    err "No path specified with -runner_inventory."
                    exit 1
                fi
                ;;
            -runner_aat_playbooks)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    RUNNER_AAT_PLAYBOOK_DIR="$1"
                else
                    err "No folder specified with -runner_aat_playbooks."
                    exit 1
                fi
                ;;
            -runner_tid_stack)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    RUNNER_TID_STACK_DIR="$1"
                else
                    err "No folder specified with -runner_tid_stack."
                    exit 1
                fi
                ;;
            -config)
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    DEFAULT_CONFIG_FILE="$1"
                else
                    err "No configuration file specified with -config."
                    exit 1
                fi
                ;;
            *)
                err "Invalid option: $1"
                exit 1
                ;;
        esac
        shift
    done
}
