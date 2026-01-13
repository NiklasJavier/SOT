#!/usr/bin/env bash
# SOT Bootstrap Library: Config Writer
# Generates the config.yaml file in the new structured format
#
# Usage: source "$SETUP_LIB_DIR/config_writer.sh"
#        write_config_file

# Prevent multiple sourcing
[[ -n "${_SOT_SETUP_CONFIG_WRITER_LOADED:-}" ]] && return 0
_SOT_SETUP_CONFIG_WRITER_LOADED=1

# Write configuration to config.yaml (new structured format)
# Expects all configuration variables to be set
write_config_file() {
    info "Writing configuration to $CONFIG_FILE..."

    cat <<- EOL > "$CONFIG_FILE"
# =============================================================================
# SOT (Server Operation Toolkit) - Configuration
# =============================================================================
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Branch: $BRANCH
# =============================================================================

# -----------------------------------------------------------------------------
# SYSTEM
# General system identification and setup parameters
# -----------------------------------------------------------------------------
system:
  name: "$SYSTEM_NAME"
  username: "$USERNAME"
  branch: "$BRANCH"
  use_defaults: "$USE_DEFAULTS"

# -----------------------------------------------------------------------------
# SSH
# SSH connection and authentication settings
# -----------------------------------------------------------------------------
ssh:
  port: "$SSH_PORT"
  key_enabled: "${SSH_KEY_FUNCTION_ENABLED:-false}"
  key_public: "${SSH_KEY_PUBLIC:-}"

# -----------------------------------------------------------------------------
# LOGGING
# Logging configuration for SOT operations
# -----------------------------------------------------------------------------
logging:
  level: "$LOG_LEVEL"
  file: "$LOG_FILE"

# -----------------------------------------------------------------------------
# PATHS
# Directory paths for SOT components
# -----------------------------------------------------------------------------
paths:
  clone_dir: "$CLONE_DIR"
  modules_dir: "$MODULES_DIR"
  scripts_dir: "$SCRIPTS_DIR"
  pipelines_dir: "$PIPELINES_DIR"
  data_dir: "$OPT_DATA_DIR"
  overrides_dir: "$OVERRIDES_DIR"
  systemlink: "$SYSTEMLINK_PATH"

# -----------------------------------------------------------------------------
# TOOLS
# Tools to install during setup
# -----------------------------------------------------------------------------
tools:
  install: "$TOOLS"

# -----------------------------------------------------------------------------
# ANSIBLE
# Local Ansible configuration
# -----------------------------------------------------------------------------
ansible:
  local_enabled: "$ANSIBLE_LOCAL_ENABLED"
  local_priority: "$ANSIBLE_LOCAL_PRIORITY"
  local_dir: "$ANSIBLE_LOCAL_DIR"

# -----------------------------------------------------------------------------
# VAULT
# Ansible Vault configuration for secrets management
# -----------------------------------------------------------------------------
vault:
  file: "$VAULT_FILE"
  secret: "$VAULT_SECRET"
  content: "$VAULT_CONTENT"
  mail: "$VAULT_MAIL"

# -----------------------------------------------------------------------------
# AAT (Ansible Automation Tools)
# External Ansible repository integration
# -----------------------------------------------------------------------------
aat:
  enabled: "$AAT_ENABLED"
  repo_url: "$AAT_REPO_URL"
  dir: "$AAT_DIR"
  branch: "$AAT_BRANCH"
  inventory_path: "${AAT_INVENTORY_PATH:-host.ini}"
  inventory_vars: "${AAT_INVENTORY_VARS:-ssh_port system_name}"

# -----------------------------------------------------------------------------
# TID (Terraform Infrastructure Deployment)
# External Terraform repository integration
# -----------------------------------------------------------------------------
tid:
  enabled: "$TID_ENABLED"
  repo_url: "$TID_REPO_URL"
  dir: "$TID_DIR"
  branch: "$TID_BRANCH"
  inventory_path: "${TID_INVENTORY_PATH:-host.ini}"
  inventory_vars: "${TID_INVENTORY_VARS:-ssh_port system_name}"

# -----------------------------------------------------------------------------
# RUNNER
# Dynamic playbook/terraform execution configuration
# -----------------------------------------------------------------------------
runner:
  enabled: "$RUNNER_ENABLED"
  default_mode: "$RUNNER_DEFAULT_MODE"
  sync_before_run: "$RUNNER_SYNC_BEFORE_RUN"
  work_dir: "$RUNNER_WORK_DIR"
  log_dir: "$RUNNER_LOG_DIR"
  default_inventory: "${RUNNER_DEFAULT_INVENTORY:-}"
  aat_playbook_dir: "${RUNNER_AAT_PLAYBOOK_DIR:-}"
  tid_stack_dir: "${RUNNER_TID_STACK_DIR:-}"

EOL

    success "Configuration saved to $CONFIG_FILE"
}
