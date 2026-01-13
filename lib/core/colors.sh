#!/usr/bin/env bash
# SOT Shared Library: Color Definitions
# Usage: source "$LIB_DIR/colors.sh"

# Prevent multiple sourcing
[[ -n "${_SOT_COLORS_LOADED:-}" ]] && return 0
_SOT_COLORS_LOADED=1

# Standard colors - use $'...' syntax for proper ANSI codes
export GREEN=$'\033[0;32m'
export RED=$'\033[0;31m'
export YELLOW=$'\033[1;33m'
export BLUE=$'\033[0;34m'
export CYAN=$'\033[0;36m'
export MAGENTA=$'\033[0;35m'
export WHITE=$'\033[1;37m'
export DIM=$'\033[2m'
export BOLD=$'\033[1m'
export NC=$'\033[0m'  # No Color / Reset

# Legacy aliases (deprecated - kept for compatibility)
export PINK="$MAGENTA"
export GREY="$DIM"

# Semantic color scheme for consistent output
export COLOR_SUCCESS="$GREEN"      # Success messages, checkmarks
export COLOR_ERROR="$RED"          # Errors, failures
export COLOR_WARNING="$YELLOW"     # Warnings, important notes
export COLOR_INFO="$CYAN"          # Info messages, progress
export COLOR_HIGHLIGHT="$MAGENTA"  # Highlighted text, values
export COLOR_LABEL="$WHITE"        # Labels, section headers
export COLOR_DIM="$DIM"            # Dimmed text, less important info
