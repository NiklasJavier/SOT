#!/usr/bin/env bash
# SOT Setup Script
# Initializes and configures the Server Operation Toolkit
#
# Usage: 
#   curl -fsSL "https://raw.githubusercontent.com/NiklasJavier/SOT/production/setup/setup_sot.sh" | bash -s -- [options]
#   # oder lokal:
#   sudo ./setup_sot.sh [options]
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

# WICHTIG: set -u erst NACH Bootstrap-Check, da BASH_SOURCE bei curl|bash nicht existiert
set -eo pipefail

# =============================================================================
# BOOTSTRAP MODE DETECTION
# =============================================================================
# Wenn via curl | bash ausgeführt, existiert BASH_SOURCE nicht.
# In diesem Fall: Repository klonen und lokales Script ausführen.

REPO_URL="https://github.com/NiklasJavier/SOT.git"
DEFAULT_CLONE_DIR="/opt/SOT"

# Parse branch early (für Bootstrap)
BOOTSTRAP_BRANCH="production"
shift_next=""
for arg in "$@"; do
    if [[ "$arg" == "-branch" ]]; then
        shift_next=true
    elif [[ "$shift_next" == "true" ]]; then
        BOOTSTRAP_BRANCH="$arg"
        shift_next=""
    fi
done

# Prüfe ob wir im Bootstrap-Modus sind (curl | bash)
# Bei curl|bash existiert BASH_SOURCE nicht oder ist leer
_BOOTSTRAP_MODE=false
if [[ -z "${BASH_SOURCE:-}" ]]; then
    _BOOTSTRAP_MODE=true
elif [[ -z "${BASH_SOURCE[0]:-}" ]]; then
    _BOOTSTRAP_MODE=true
elif [[ "${BASH_SOURCE[0]}" == "bash" ]] || [[ "${BASH_SOURCE[0]}" == "-bash" ]]; then
    _BOOTSTRAP_MODE=true
fi

if [[ "$_BOOTSTRAP_MODE" == "true" ]]; then
    echo ""
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║     SOT Bootstrap - Server Operation Toolkit              ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "  → Bootstrap-Modus erkannt (curl | bash)"
    echo "  → Klone Repository nach $DEFAULT_CLONE_DIR..."
    echo ""
    
    # Git installieren falls nicht vorhanden
    if ! command -v git &>/dev/null; then
        echo "  → Installiere Git..."
        if command -v apt-get &>/dev/null; then
            apt-get update -qq && apt-get install -y -qq git
        elif command -v yum &>/dev/null; then
            yum install -y -q git
        elif command -v dnf &>/dev/null; then
            dnf install -y -q git
        else
            echo "  ✗ Fehler: Git konnte nicht installiert werden."
            exit 1
        fi
    fi
    
    # Repository klonen oder aktualisieren
    if [[ -d "$DEFAULT_CLONE_DIR/.git" ]]; then
        echo "  → Repository existiert bereits, aktualisiere..."
        cd "$DEFAULT_CLONE_DIR"
        git fetch --all --quiet
        git checkout "$BOOTSTRAP_BRANCH" --quiet 2>/dev/null || git checkout -b "$BOOTSTRAP_BRANCH" "origin/$BOOTSTRAP_BRANCH" --quiet
        git pull --quiet
    else
        echo "  → Klone Branch: $BOOTSTRAP_BRANCH"
        git clone -b "$BOOTSTRAP_BRANCH" --single-branch --quiet "$REPO_URL" "$DEFAULT_CLONE_DIR"
    fi
    
    echo "  ✓ Repository bereit"
    echo ""
    echo "  → Starte lokales Setup-Script..."
    echo ""
    
    # Lokales Script ausführen mit allen Argumenten
    exec bash "$DEFAULT_CLONE_DIR/setup/setup_sot.sh" "$@"
fi

# =============================================================================
# LOKALER MODUS - Normale Ausführung
# =============================================================================

# Ab hier ist BASH_SOURCE garantiert verfügbar, aktiviere strict mode
set -u

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
