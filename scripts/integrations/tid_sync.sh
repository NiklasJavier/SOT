#!/usr/bin/env bash
# =============================================================================
# @cmd: tid sync
# @category: sync
# @description: TID-Repository synchronisieren
# @usage: SOT tid sync [--branch <branch>]
# @example: SOT tid sync --branch feature/new-module
# =============================================================================
## Klont oder aktualisiert das TID (Terraform Infrastructure Deployment) Repository.
## Kann via tid_enabled in config.yaml deaktiviert werden.
## Timeout konfigurierbar via SOT_GIT_TIMEOUT (default: 120s).
# =============================================================================

set -euo pipefail

# Load shared library
SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../../lib/init.sh
source "$SCRIPT_ROOT/lib/init.sh"

# Configuration
GIT_TIMEOUT="${SOT_GIT_TIMEOUT:-120}"  # 2 minutes default timeout for git operations

BRANCH_OVERRIDE=""
FILTERED_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      shift
      if [[ $# -eq 0 ]]; then
        err "--branch requires a value."
        exit 1
      fi
      BRANCH_OVERRIDE="$1"
      shift
      ;;
    *)
      FILTERED_ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${FILTERED_ARGS[@]}"

CONFIG_FILE_PATH=""
if CONFIG_FILE_PATH=$(find_config_file_arg "$@"); then
  :
else
  err "config.yaml not found in provided arguments. Aborting."
  exit 1
fi

# Use shared YAML parser to extract needed values
TID_REPO_URL=$(get_yaml_value "$CONFIG_FILE_PATH" "tid_repo_url" "https://github.com/NiklasJavier/TID.git")
TID_DIR=$(get_yaml_value "$CONFIG_FILE_PATH" "tid_dir" "/opt/TID")
TID_ENABLED=$(get_yaml_value "$CONFIG_FILE_PATH" "tid_enabled" "true")
TID_BRANCH=$(get_yaml_value "$CONFIG_FILE_PATH" "tid_branch" "main")

if [[ -n "$BRANCH_OVERRIDE" ]]; then
  TID_BRANCH="$BRANCH_OVERRIDE"
fi

if ! is_true "$TID_ENABLED"; then
  info "TID integration disabled (tid_enabled != true). Nothing to do."
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  err "git is required to sync TID. Please install git and retry."
  exit 1
fi

info "Syncing TID at ${YELLOW}$TID_DIR${NC} from ${YELLOW}$TID_REPO_URL${NC} (branch ${YELLOW}$TID_BRANCH${NC})..."
ensure_dir "$TID_DIR"

if [[ -d "$TID_DIR/.git" ]]; then
  if ! run_with_timeout "$GIT_TIMEOUT" git -C "$TID_DIR" fetch origin "$TID_BRANCH"; then
    warn "'git fetch' failed or timed out. Removing local repository for a clean clone..."
    rm -rf "$TID_DIR"
  else
    if ! run_with_timeout "$GIT_TIMEOUT" git -C "$TID_DIR" checkout "$TID_BRANCH" >/dev/null 2>&1; then
      warn "branch '$TID_BRANCH' is unavailable locally. Re-cloning..."
      rm -rf "$TID_DIR"
    elif ! run_with_timeout "$GIT_TIMEOUT" git -C "$TID_DIR" pull --ff-only origin "$TID_BRANCH"; then
      warn "'git pull' failed or timed out. Re-cloning repository..."
      rm -rf "$TID_DIR"
    fi
  fi
fi

if [[ ! -d "$TID_DIR/.git" ]]; then
  rm -rf "$TID_DIR"
  if ! run_with_timeout "$GIT_TIMEOUT" git clone --depth 1 --single-branch --branch "$TID_BRANCH" "$TID_REPO_URL" "$TID_DIR"; then
    err "Failed to clone TID repository (timeout: ${GIT_TIMEOUT}s)."
    exit 1
  fi
fi

success "TID sync completed."


