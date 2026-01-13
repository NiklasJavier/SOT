#!/usr/bin/env bash
# SOT Shared Library: Initialization
# Usage: source "$SOT_ROOT/lib/init.sh"
#
# This file loads all shared library components.
# It automatically determines the library directory.

# Prevent multiple sourcing
[[ -n "${_SOT_LIB_INIT_LOADED:-}" ]] && return 0
_SOT_LIB_INIT_LOADED=1

# Determine library directory
if [[ -z "${SOT_LIB_DIR:-}" ]]; then
  SOT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

export SOT_LIB_DIR

# Load all library components (new structure)
source "$SOT_LIB_DIR/core/colors.sh"
source "$SOT_LIB_DIR/core/yaml_parser.sh"
source "$SOT_LIB_DIR/core/helpers.sh"
source "$SOT_LIB_DIR/cli/integrations.sh"

# Set SOT_ROOT if not already set
if [[ -z "${SOT_ROOT:-}" ]]; then
  SOT_ROOT="$(cd "$SOT_LIB_DIR/.." && pwd)"
  export SOT_ROOT
fi

