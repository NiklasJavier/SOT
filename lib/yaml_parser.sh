#!/bin/bash
# SOT Shared Library: YAML Parser
# Usage: source "$LIB_DIR/yaml_parser.sh"
#
# Functions:
#   parse_yaml_to_vars <file>        - Parse YAML and set shell variables (flat)
#   parse_yaml_to_array <file> <array_name> - Parse YAML into associative array (flat)
#   get_yaml_value <file> <key> [default] - Get single value from YAML (flat)
#   parse_nested_yaml <file> <array_name> - Parse nested YAML (section.key format)
#   get_nested_value <file> <section.key> [default] - Get nested value

# Prevent multiple sourcing
[[ -n "${_SOT_YAML_PARSER_LOADED:-}" ]] && return 0
_SOT_YAML_PARSER_LOADED=1

# Parse a simple YAML file and set shell variables
# Arguments:
#   $1 - Path to YAML file
# Returns:
#   0 on success, 1 on failure
# Side effects:
#   Sets shell variables for each key in the YAML file
parse_yaml_to_vars() {
  local file="$1"
  
  if [[ ! -f "$file" ]]; then
    echo "YAML file not found: $file" >&2
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Remove comments and carriage returns
    line="${line%%#*}"
    line="${line%%$'\r'}"
    
    # Skip empty lines
    [[ -z "${line//[[:space:]]/}" ]] && continue

    # Only process lines containing ':'
    if [[ "$line" == *":"* ]]; then
      # Extract key and value
      local var_name var_value
      var_name=$(echo "$line" | cut -d ':' -f 1 | xargs | tr ' ' '_' | tr '-' '_')
      var_value=$(echo "$line" | cut -d ':' -f 2- | xargs)

      # Remove surrounding quotes if present
      var_value="${var_value#\"}"
      var_value="${var_value%\"}"
      var_value="${var_value#\'}"
      var_value="${var_value%\'}"

      # Set the variable (using printf -v for safety)
      printf -v "$var_name" '%s' "$var_value"
    fi
  done < "$file"

  return 0
}

# Parse a simple YAML file into an associative array
# Arguments:
#   $1 - Path to YAML file
#   $2 - Name of associative array (must be declared with 'declare -A' before calling)
# Returns:
#   0 on success, 1 on failure
parse_yaml_to_array() {
  local file="$1"
  local -n _arr="$2"

  if [[ ! -f "$file" ]]; then
    echo "YAML file not found: $file" >&2
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Remove comments and carriage returns
    line="${line%%#*}"
    line="${line%%$'\r'}"
    
    # Skip empty lines
    [[ -z "${line//[[:space:]]/}" ]] && continue

    # Only process lines containing ':'
    if [[ "$line" == *":"* ]]; then
      local key value
      key=$(echo "$line" | cut -d ':' -f 1 | xargs)
      value=$(echo "$line" | cut -d ':' -f 2- | xargs)

      # Remove surrounding quotes if present
      value="${value#\"}"
      value="${value%\"}"
      value="${value#\'}"
      value="${value%\'}"

      _arr["$key"]="$value"
    fi
  done < "$file"

  return 0
}

# Get a single value from a YAML file
# Arguments:
#   $1 - Path to YAML file
#   $2 - Key to look for
#   $3 - Default value (optional)
# Returns:
#   The value on stdout, or default if not found
get_yaml_value() {
  local file="$1"
  local search_key="$2"
  local default="${3:-}"

  if [[ ! -f "$file" ]]; then
    echo "$default"
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line%%$'\r'}"
    [[ -z "${line//[[:space:]]/}" ]] && continue

    if [[ "$line" == *":"* ]]; then
      local key value
      key=$(echo "$line" | cut -d ':' -f 1 | xargs)
      value=$(echo "$line" | cut -d ':' -f 2- | xargs)

      if [[ "$key" == "$search_key" ]]; then
        # Remove surrounding quotes
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        echo "$value"
        return 0
      fi
    fi
  done < "$file"

  echo "$default"
  return 0
}

# =============================================================================
# NESTED YAML SUPPORT (for structured config files)
# =============================================================================

# Parse a nested YAML file into an associative array
# Keys are stored as "section.key" format (e.g., "system.name", "ssh.port")
# Arguments:
#   $1 - Path to YAML file
#   $2 - Name of associative array (must be declared with 'declare -A' before calling)
# Returns:
#   0 on success, 1 on failure
parse_nested_yaml() {
  local file="$1"
  local -n _narr="$2"

  if [[ ! -f "$file" ]]; then
    echo "YAML file not found: $file" >&2
    return 1
  fi

  local current_section=""
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Remove comments and carriage returns
    line="${line%%#*}"
    line="${line%%$'\r'}"
    
    # Skip empty lines
    [[ -z "${line//[[:space:]]/}" ]] && continue

    # Check if line starts with spaces (child key) or not (section header)
    if [[ "$line" =~ ^[[:space:]]+ ]]; then
      # This is a child key (indented)
      if [[ "$line" == *":"* && -n "$current_section" ]]; then
        local key value
        key=$(echo "$line" | cut -d ':' -f 1 | xargs | tr '-' '_')
        value=$(echo "$line" | cut -d ':' -f 2- | xargs)

        # Remove surrounding quotes
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"

        # Store with section prefix
        _narr["${current_section}.${key}"]="$value"
      fi
    else
      # This is a section header or flat key
      if [[ "$line" == *":"* ]]; then
        local key value
        key=$(echo "$line" | cut -d ':' -f 1 | xargs | tr '-' '_')
        value=$(echo "$line" | cut -d ':' -f 2- | xargs)

        if [[ -z "$value" ]]; then
          # Section header (no value after colon)
          current_section="$key"
        else
          # Flat key-value pair (for backwards compatibility)
          value="${value#\"}"
          value="${value%\"}"
          value="${value#\'}"
          value="${value%\'}"
          _narr["$key"]="$value"
          current_section=""
        fi
      fi
    fi
  done < "$file"

  return 0
}

# Get a single nested value from a YAML file
# Arguments:
#   $1 - Path to YAML file
#   $2 - Key in "section.key" format (e.g., "system.name", "ssh.port")
#   $3 - Default value (optional)
# Returns:
#   The value on stdout, or default if not found
get_nested_value() {
  local file="$1"
  local search_key="$2"
  local default="${3:-}"

  if [[ ! -f "$file" ]]; then
    echo "$default"
    return 1
  fi

  # Split search_key into section and key
  local search_section search_subkey
  if [[ "$search_key" == *"."* ]]; then
    search_section="${search_key%%.*}"
    search_subkey="${search_key#*.}"
  else
    # Flat key (no section)
    search_section=""
    search_subkey="$search_key"
  fi

  local current_section=""
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line%%$'\r'}"
    [[ -z "${line//[[:space:]]/}" ]] && continue

    if [[ "$line" =~ ^[[:space:]]+ ]]; then
      # Indented line (child key)
      if [[ "$line" == *":"* && "$current_section" == "$search_section" ]]; then
        local key value
        key=$(echo "$line" | cut -d ':' -f 1 | xargs | tr '-' '_')
        value=$(echo "$line" | cut -d ':' -f 2- | xargs)

        if [[ "$key" == "$search_subkey" ]]; then
          value="${value#\"}"
          value="${value%\"}"
          value="${value#\'}"
          value="${value%\'}"
          echo "$value"
          return 0
        fi
      fi
    else
      # Section header or flat key
      if [[ "$line" == *":"* ]]; then
        local key value
        key=$(echo "$line" | cut -d ':' -f 1 | xargs | tr '-' '_')
        value=$(echo "$line" | cut -d ':' -f 2- | xargs)

        if [[ -z "$value" ]]; then
          # Section header
          current_section="$key"
        else
          # Flat key - check if it matches (for backwards compatibility)
          if [[ -z "$search_section" && "$key" == "$search_subkey" ]]; then
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            echo "$value"
            return 0
          fi
          current_section=""
        fi
      fi
    fi
  done < "$file"

  echo "$default"
  return 0
}

# Convert nested config to flat format for backwards compatibility
# Arguments:
#   $1 - Name of source nested array
#   $2 - Name of target flat array
# Mapping: section.key -> section_key (e.g., system.name -> system_name)
convert_nested_to_flat() {
  local -n _src="$1"
  local -n _dst="$2"
  
  for key in "${!_src[@]}"; do
    local flat_key="${key//./_}"
    _dst["$flat_key"]="${_src[$key]}"
  done
}

# Smart config loader - detects format and loads appropriately
# Arguments:
#   $1 - Path to YAML file
#   $2 - Name of associative array
# Returns:
#   0 on success, 1 on failure
# Note: Returns flat keys regardless of input format
load_config() {
  local file="$1"
  local -n _cfg="$2"

  if [[ ! -f "$file" ]]; then
    echo "Config file not found: $file" >&2
    return 1
  fi

  # Check if file has nested structure (sections with indented children)
  local has_nested=false
  local in_section=false
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ -z "${line//[[:space:]]/}" ]] && continue
    
    if [[ "$line" =~ ^[^[:space:]].*:[[:space:]]*$ ]]; then
      # Line ends with just ":" - likely a section header
      in_section=true
    elif [[ "$line" =~ ^[[:space:]]+ && "$in_section" == true ]]; then
      # Indented line after section header
      has_nested=true
      break
    else
      in_section=false
    fi
  done < "$file"

  if [[ "$has_nested" == true ]]; then
    # Parse as nested, then convert to flat
    declare -A _nested_tmp
    parse_nested_yaml "$file" _nested_tmp
    convert_nested_to_flat _nested_tmp _cfg
  else
    # Parse as flat directly
    parse_yaml_to_array "$file" _cfg
  fi

  return 0
}
