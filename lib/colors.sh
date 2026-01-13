#!/bin/bash
# SOT Shared Library: Color Definitions
# Usage: source "$LIB_DIR/colors.sh"

# Prevent multiple sourcing
[[ -n "${_SOT_COLORS_LOADED:-}" ]] && return 0
_SOT_COLORS_LOADED=1

# Standard colors
export GREEN='\033[0;32m'
export RED='\033[0;31m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PINK='\033[0;35m'
export CYAN='\033[0;36m'
export GREY='\033[1;90m'
export BOLD='\033[1m'
export NC='\033[0m'  # No Color / Reset

# Semantic aliases
export COLOR_SUCCESS="$GREEN"
export COLOR_ERROR="$RED"
export COLOR_WARNING="$YELLOW"
export COLOR_INFO="$BLUE"
export COLOR_HIGHLIGHT="$PINK"
export COLOR_MUTED="$GREY"
