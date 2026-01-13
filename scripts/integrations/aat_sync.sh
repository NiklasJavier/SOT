#!/usr/bin/env bash

# aat sync: Synchronize the AAT repository based on values in config.yaml
# This script is invoked via: SOT aat sync
# The SOT CLI appends standard arguments including modules_dir, CONFIG_FILE, username, vault_file, vault_secret, opt_data_dir, clone_dir, systemlink_path, log_file, branch

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
AAT_REPO_URL=$(get_yaml_value "$CONFIG_FILE_PATH" "aat_repo_url" "https://github.com/NiklasJavier/AAT.git")
AAT_DIR=$(get_yaml_value "$CONFIG_FILE_PATH" "aat_dir" "/opt/AAT")
AAT_ENABLED=$(get_yaml_value "$CONFIG_FILE_PATH" "aat_enabled" "true")
AAT_BRANCH=$(get_yaml_value "$CONFIG_FILE_PATH" "aat_branch" "main")

if [[ -n "$BRANCH_OVERRIDE" ]]; then
  AAT_BRANCH="$BRANCH_OVERRIDE"
fi

if ! is_true "$AAT_ENABLED"; then
  info "AAT integration disabled (aat_enabled != true). Nothing to do."
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  err "git is required to sync AAT. Please install git and retry."
  exit 1
fi

info "Syncing AAT at ${YELLOW}$AAT_DIR${NC} from ${YELLOW}$AAT_REPO_URL${NC} (branch ${YELLOW}$AAT_BRANCH${NC})..."
ensure_dir "$AAT_DIR"

if [[ -d "$AAT_DIR/.git" ]]; then
  if ! run_with_timeout "$GIT_TIMEOUT" git -C "$AAT_DIR" fetch origin "$AAT_BRANCH"; then
    warn "'git fetch' failed or timed out. Removing local repository for a clean clone..."
    rm -rf "$AAT_DIR"
  else
    if ! run_with_timeout "$GIT_TIMEOUT" git -C "$AAT_DIR" checkout "$AAT_BRANCH" >/dev/null 2>&1; then
      warn "branch '$AAT_BRANCH' is unavailable locally. Re-cloning..."
      rm -rf "$AAT_DIR"
    elif ! run_with_timeout "$GIT_TIMEOUT" git -C "$AAT_DIR" pull --ff-only origin "$AAT_BRANCH"; then
      warn "'git pull' failed or timed out. Re-cloning repository..."
      rm -rf "$AAT_DIR"
    fi
  fi
fi

if [[ ! -d "$AAT_DIR/.git" ]]; then
  rm -rf "$AAT_DIR"
  if ! run_with_timeout "$GIT_TIMEOUT" git clone --depth 1 --single-branch --branch "$AAT_BRANCH" "$AAT_REPO_URL" "$AAT_DIR"; then
    err "Failed to clone AAT repository (timeout: ${GIT_TIMEOUT}s)."
    exit 1
  fi
fi

success "AAT sync completed."


