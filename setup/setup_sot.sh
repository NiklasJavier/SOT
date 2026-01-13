#!/usr/bin/env bash
# SOT Setup Script
# Initializes and configures the Server Operation Toolkit
#
# Usage: sudo ./setup_sot.sh [options]
#
# Options:
#   -branch <name>          Branch to use (default: production)
#   -systemname <name>      System name
#   -username <name>        Username
#   -port <number>          SSH port
#   -tools <list>           Tools to install (space-separated)
#   -key <pubkey>           SSH public key
#   -aat_enabled true|false Enable AAT integration
#   -tid_enabled true|false Enable TID integration
#   -config <path>          Path to config file
#
# See README.md for full documentation.

set -euo pipefail

# =============================================================================
# INITIALIZATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load setup library (includes all dependencies)
# shellcheck source=../lib/core/setup/init.sh
source "$SOT_ROOT/lib/core/setup/init.sh"

# =============================================================================
# DEFAULT VALUES
# =============================================================================

DEFAULT_CONFIG_FILE="${SOT_DEFAULT_CONFIG:-$SCRIPT_DIR/../services/default_config.yml}"
DEFAULT_BRANCH_HINT="production"

REPO_URL="https://github.com/NiklasJavier/DevOpsToolkit.git"
BRANCH=""
BRANCH_DIR=""
USE_DEFAULTS=""

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

# Parse early args that affect config loading
ORIGINAL_ARGS=("$@")
parse_early_args "${ORIGINAL_ARGS[@]}"

# Load and apply defaults from config file
load_default_config "$DEFAULT_CONFIG_FILE"
apply_config_defaults

# Parse all command line arguments
parse_setup_args "${ORIGINAL_ARGS[@]}"

# Ensure SDKMAN is in tools list
ensure_sdkman_default

# =============================================================================
# FINALIZE CONFIGURATION
# =============================================================================

# Set default branch if not specified
if [[ -z "$BRANCH" ]]; then
    USE_DEFAULTS=true
    BRANCH="production"
fi

# Generate dynamic defaults based on current values
generate_dynamic_defaults

# Set derived paths
BRANCH_DIR="$SETUP_DIR/$BRANCH"
SETTINGS_DIR="$BRANCH_DIR/.settings"
CONFIG_FILE="$SETTINGS_DIR/config.yaml"

# =============================================================================
# TASK DEFINITIONS
# =============================================================================

# Wrapper functions that call the library tasks
# This allows for easy customization and ordering

checkSettingsDirExist() { task_check_settings_dir; }
startOverview() { task_show_overview; }
checkRootPermissions() { task_check_root; }
copyAndSetTheRepository() { task_clone_repository; }
settingsEnvironmentFolder() { task_create_settings_folder; }
editCliWrapperFile() { task_edit_cli_wrapper; }
createCliWrapperSbinLink() { task_create_cli_symlink; }
makeScriptExecutable() { task_make_scripts_executable; }
cloneOrUpdateAAT() { task_clone_aat; }
cloneOrUpdateTID() { task_clone_tid; }
writeConfigFile() { write_config_file; }
installAvailableTools() { task_install_tools; }
initalScriptOverview() { task_show_final_overview; }

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Define task execution order
SETUP_TASKS=(
    checkSettingsDirExist
    startOverview
    checkRootPermissions
    copyAndSetTheRepository
    settingsEnvironmentFolder
    editCliWrapperFile
    createCliWrapperSbinLink
    makeScriptExecutable
    cloneOrUpdateAAT
    cloneOrUpdateTID
    writeConfigFile
    installAvailableTools
    initalScriptOverview
)

# Run all tasks with progress indication
run_tasks "${SETUP_TASKS[@]}"
