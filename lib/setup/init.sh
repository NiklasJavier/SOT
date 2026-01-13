#!/usr/bin/env bash
# SOT Setup Library: Initialization
# Loads all setup library components
#
# Usage: source "$SOT_ROOT/lib/setup/init.sh"

# Prevent multiple sourcing
[[ -n "${_SOT_SETUP_LIB_INIT_LOADED:-}" ]] && return 0
_SOT_SETUP_LIB_INIT_LOADED=1

# Determine library directory
SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SETUP_LIB_DIR

# Load main SOT library first (colors, helpers, yaml_parser)
source "$SETUP_LIB_DIR/../init.sh"

# Load setup-specific components
source "$SETUP_LIB_DIR/config_defaults.sh"
source "$SETUP_LIB_DIR/args_parser.sh"
source "$SETUP_LIB_DIR/tasks.sh"
source "$SETUP_LIB_DIR/config_writer.sh"
source "$SETUP_LIB_DIR/runner.sh"
