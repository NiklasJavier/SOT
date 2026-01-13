#!/bin/bash
# SOT Shared Library: Helper Functions
# Usage: source "$LIB_DIR/helpers.sh"
#
# Functions:
#   is_true <value>           - Check if value is truthy
#   log_command <message>     - Log command to log file
#   ensure_dir <path>         - Ensure directory exists
#   resolve_path <path>       - Resolve relative path to absolute

# Prevent multiple sourcing
[[ -n "${_SOT_HELPERS_LOADED:-}" ]] && return 0
_SOT_HELPERS_LOADED=1

# Check if a value is truthy (true, 1, yes, on)
# Arguments:
#   $1 - Value to check
# Returns:
#   0 if truthy, 1 otherwise
is_true() {
  case "${1,,}" in
    true|1|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

# Check if a value is falsy (false, 0, no, off, empty)
# Arguments:
#   $1 - Value to check
# Returns:
#   0 if falsy, 1 otherwise
is_false() {
  case "${1,,}" in
    false|0|no|off|"") return 0 ;;
    *) return 1 ;;
  esac
}

# Log a command execution to the configured log file
# Arguments:
#   $@ - Command/message to log
# Environment:
#   SOT_LOG_FILE or log_file - Path to log file
# Returns:
#   0 always (logging failures are silent)
log_command() {
  local log_target="${SOT_LOG_FILE:-${log_file:-}}"
  
  [[ -z "$log_target" ]] && return 0
  
  # Try to write to log, fail silently
  printf '%s - %s - %s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" \
    "${USER:-unknown}" \
    "$*" >> "$log_target" 2>/dev/null || true
    
  return 0
}

# Ensure a directory exists, create if necessary
# Arguments:
#   $1 - Directory path
# Returns:
#   0 on success, 1 on failure
ensure_dir() {
  local dir="$1"
  
  if [[ -d "$dir" ]]; then
    return 0
  fi
  
  if mkdir -p "$dir" 2>/dev/null; then
    return 0
  fi
  
  echo "Failed to create directory: $dir" >&2
  return 1
}

# Resolve a path to its absolute form
# Arguments:
#   $1 - Path to resolve
# Returns:
#   Absolute path on stdout
resolve_path() {
  local path="$1"
  
  # Already absolute
  if [[ "$path" == /* ]]; then
    echo "$path"
    return 0
  fi
  
  # Expand ~ to home directory
  if [[ "$path" == ~* ]]; then
    path="${path/#\~/$HOME}"
  fi
  
  # Make relative path absolute
  if [[ -e "$path" ]]; then
    cd "$(dirname "$path")" && echo "$(pwd)/$(basename "$path")"
  else
    echo "$(pwd)/$path"
  fi
}

# Print an error message to stderr
# Arguments:
#   $@ - Error message
err() {
  echo -e "${RED:-}Error: $*${NC:-}" >&2
}

# Print a warning message to stderr
# Arguments:
#   $@ - Warning message
warn() {
  echo -e "${YELLOW:-}Warning: $*${NC:-}" >&2
}

# Print an info message
# Arguments:
#   $@ - Info message
info() {
  echo -e "${GREY:-}$*${NC:-}"
}

# Print a success message
# Arguments:
#   $@ - Success message
success() {
  echo -e "${GREEN:-}$*${NC:-}"
}
