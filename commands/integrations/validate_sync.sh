#!/usr/bin/env bash
# =============================================================================
# @cmd: integrations validate
# @category: sync
# @description: AAT/TID Synchronisierungsstatus prüfen
# @usage: SOT integrations validate
# @example: SOT integrations validate
# =============================================================================
## Prüft ob AAT und TID Repositories korrekt synchronisiert sind.
## Validiert: Verzeichnis existiert, korrekter Branch, erwartete Dateien.
## Gibt detaillierte Statusmeldungen für jede Integration aus.
# =============================================================================

set -euo pipefail

# Load shared library
SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../../lib/init.sh
source "$SCRIPT_ROOT/lib/init.sh"

CONFIG_FILE_PATH=""
if CONFIG_FILE_PATH=$(find_config_file_arg "$@"); then
  :
else
  err "config.yaml not found in provided arguments. Aborting."
  exit 1
fi

# Use shared YAML parser to extract needed values
AAT_ENABLED=$(get_yaml_value "$CONFIG_FILE_PATH" "aat_enabled" "true")
AAT_DIR=$(get_yaml_value "$CONFIG_FILE_PATH" "aat_dir" "/opt/AAT")
AAT_BRANCH=$(get_yaml_value "$CONFIG_FILE_PATH" "aat_branch" "main")
TID_ENABLED=$(get_yaml_value "$CONFIG_FILE_PATH" "tid_enabled" "true")
TID_DIR=$(get_yaml_value "$CONFIG_FILE_PATH" "tid_dir" "/opt/TID")
TID_BRANCH=$(get_yaml_value "$CONFIG_FILE_PATH" "tid_branch" "main")

status_ok=true

info "Validating integration state..."

if is_true "$AAT_ENABLED"; then
  info "Checking AAT repository at ${YELLOW}$AAT_DIR${NC}..."
  if [[ ! -d "$AAT_DIR/.git" ]]; then
    err "  ✗ No git repository found at $AAT_DIR. Run 'SOT integrations aat_sync'."
    status_ok=false
  else
    current_branch=$(git -C "$AAT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    if [[ "$current_branch" != "$AAT_BRANCH" ]]; then
      warn "  ! Expected branch '$AAT_BRANCH' but repository is on '$current_branch'."
      status_ok=false
    fi
    if [[ -f "$AAT_DIR/playbooks/site.yml" || -f "$AAT_DIR/ansible/playbooks/site.yml" ]]; then
      success "  ✓ Required playbook found."
    else
      err "  ✗ Expected playbook 'playbooks/site.yml' not found in AAT repository."
      status_ok=false
    fi
  fi
else
  info "AAT integration disabled — skipping."
fi

echo
if is_true "$TID_ENABLED"; then
  info "Checking TID repository at ${YELLOW}$TID_DIR${NC}..."
  if [[ ! -d "$TID_DIR/.git" ]]; then
    err "  ✗ No git repository found at $TID_DIR. Run 'SOT integrations tid_sync'."
    status_ok=false
  else
    current_branch=$(git -C "$TID_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    if [[ "$current_branch" != "$TID_BRANCH" ]]; then
      warn "  ! Expected branch '$TID_BRANCH' but repository is on '$current_branch'."
      status_ok=false
    fi
    if [[ -f "$TID_DIR/modules/proxmox/main.tf" ]]; then
      success "  ✓ Required Terraform module found."
    else
      err "  ✗ Expected module 'modules/proxmox/main.tf' not found in TID repository."
      status_ok=false
    fi
  fi
else
  info "TID integration disabled — skipping."
fi

echo
if $status_ok; then
  success "All integrations validated successfully."
else
  err "One or more integrations require attention."
  exit 1
fi
