#!/usr/bin/env bash
# SOT Setup Library: Configuration Defaults
# Handles default configuration loading and generation
#
# Usage: source "$SETUP_LIB_DIR/config_defaults.sh"

# Prevent multiple sourcing
[[ -n "${_SOT_SETUP_CONFIG_DEFAULTS_LOADED:-}" ]] && return 0
_SOT_SETUP_CONFIG_DEFAULTS_LOADED=1

# Associative array to store config defaults
declare -A CONFIG_DEFAULTS

# Load default configuration from YAML file
# Arguments:
#   $1 - Path to default config file
# Side effects:
#   Populates CONFIG_DEFAULTS array
load_default_config() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        local tmp_file=""
        local source_url="${SOT_DEFAULT_CONFIG_URL:-https://raw.githubusercontent.com/NiklasJavier/SOT/${DEFAULT_BRANCH_HINT}/config/default_config.yml}"
        tmp_file="$(mktemp)"
        
        if curl -fsSL "$source_url" -o "$tmp_file"; then
            info "Default configuration not found locally. Downloaded from ${YELLOW}$source_url${NC}"
            file="$tmp_file"
            DEFAULT_CONFIG_FILE="$tmp_file"
        else
            err "Default configuration missing: $1"
            err "Additionally failed to download configuration from: $source_url"
            exit 1
        fi
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line%%$'\r'}"
        
        [[ -z "${line//[[:space:]]/}" ]] && continue

        if [[ "$line" =~ ^([a-zA-Z0-9_]+):[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            value="${value%\"}"
            value="${value#\"}"
            CONFIG_DEFAULTS["$key"]="$value"
        fi
    done < "$file"
}

# Apply loaded config defaults to shell variables
# Side effects:
#   Sets uppercase shell variables for each config key
apply_config_defaults() {
    for key in "${!CONFIG_DEFAULTS[@]}"; do
        local var_name="${key^^}"
        var_name="${var_name//-/_}"
        local value="${CONFIG_DEFAULTS[$key]}"
        printf -v "$var_name" '%s' "$value"
    done
}

# Ensure SDKMAN is in the tools list and deduplicate
# Side effects:
#   Modifies TOOLS variable
ensure_sdkman_default() {
    local has_sdkman="false"
    
    for token in $TOOLS; do
        if [[ $token == sdkman* ]]; then
            has_sdkman="true"
            break
        fi
    done

    if [[ "$has_sdkman" == "false" ]]; then
        TOOLS="$TOOLS sdkman"
    fi

    # Deduplicate tools
    declare -A seen_tools=()
    local normalized=""
    
    for token in $TOOLS; do
        [[ -z "$token" ]] && continue
        [[ -n "${seen_tools[$token]:-}" ]] && continue
        seen_tools[$token]=1
        
        if [[ -z "$normalized" ]]; then
            normalized="$token"
        else
            normalized+=" $token"
        fi
    done
    
    TOOLS="$normalized"
}

# Generate dynamic default values based on other settings
# Side effects:
#   Sets various configuration variables
generate_dynamic_defaults() {
    # Username generation
    if [[ -z "$USERNAME" || "$USERNAME" == "__GENERATE_USERNAME__" ]]; then
        # Use openssl for better macOS compatibility
        if command -v openssl &>/dev/null; then
            USERNAME="$(openssl rand -base64 20 | tr -dc '[:upper:]' | head -c 11)"
        else
            USERNAME="$(LC_ALL=C tr -dc '[:upper:]' < /dev/urandom | head -c 11)"
        fi
    fi

    # System name
    if [[ -z "$SYSTEM_NAME" || "$SYSTEM_NAME" == "__GENERATE_SYSTEM_NAME__" ]]; then
        SYSTEM_NAME="SRV-$USERNAME"
    fi

    # Base directories
    [[ -z "$CLONE_DIR" ]] && CLONE_DIR="/etc/DevOpsToolkit"
    
    BIN_DIR="$CLONE_DIR/bin"
    SETUP_DIR="$CLONE_DIR/setup"
    CONFIG_DIR="$CLONE_DIR/config"
    CLI_FILE="$BIN_DIR/sot"

    # Module directories
    if [[ -z "${MODULES_DIR:-}" || "$MODULES_DIR" == "__GENERATE_MODULES_DIR__" ]]; then
        MODULES_DIR="$CLONE_DIR/modules"
    fi

    if [[ -z "${COMMANDS_DIR:-}" || "${COMMANDS_DIR:-}" == "__GENERATE_COMMANDS_DIR__" ]]; then
        COMMANDS_DIR="$CLONE_DIR/commands"
    fi

    if [[ -z "${PIPELINES_DIR:-}" || "${PIPELINES_DIR:-}" == "__GENERATE_PIPELINES_DIR__" ]]; then
        PIPELINES_DIR="$CLONE_DIR/pipelines"
    fi

    # Ansible settings
    if [[ -z "$ANSIBLE_LOCAL_DIR" || "$ANSIBLE_LOCAL_DIR" == "__GENERATE_ANSIBLE_LOCAL_DIR__" ]]; then
        ANSIBLE_LOCAL_DIR="$MODULES_DIR/ansible"
    fi

    if [[ -z "$OVERRIDES_DIR" || "$OVERRIDES_DIR" == "__GENERATE_OVERRIDES_DIR__" ]]; then
        OVERRIDES_DIR="$CLONE_DIR/config/overrides"
    fi

    [[ -z "$ANSIBLE_LOCAL_ENABLED" ]] && ANSIBLE_LOCAL_ENABLED="true"
    [[ -z "$ANSIBLE_LOCAL_PRIORITY" ]] && ANSIBLE_LOCAL_PRIORITY="true"

    # Data directories
    if [[ -z "$OPT_DATA_DIR" || "$OPT_DATA_DIR" == "__GENERATE_OPT_DATA_DIR__" ]]; then
        OPT_DATA_DIR="/opt/$SYSTEM_NAME"
    fi

    # Runner settings
    if [[ -z "$RUNNER_WORK_DIR" || "$RUNNER_WORK_DIR" == "__GENERATE_RUNNER_WORK_DIR__" ]]; then
        RUNNER_WORK_DIR="$OPT_DATA_DIR/runner"
    fi

    if [[ -z "$RUNNER_LOG_DIR" || "$RUNNER_LOG_DIR" == "__GENERATE_RUNNER_LOG_DIR__" ]]; then
        RUNNER_LOG_DIR="$RUNNER_WORK_DIR/logs"
    fi

    [[ -z "$RUNNER_DEFAULT_MODE" ]] && RUNNER_DEFAULT_MODE="aat"
    [[ -z "$RUNNER_SYNC_BEFORE_RUN" ]] && RUNNER_SYNC_BEFORE_RUN="true"
    [[ -z "$RUNNER_ENABLED" ]] && RUNNER_ENABLED="true"

    # Integration branches
    [[ -z "$AAT_BRANCH" ]] && AAT_BRANCH="main"
    [[ -z "$TID_BRANCH" ]] && TID_BRANCH="main"

    # Vault settings
    if [[ -z "$VAULT_FILE" || "$VAULT_FILE" == "__GENERATE_VAULT_FILE__" ]]; then
        VAULT_FILE="$OPT_DATA_DIR/vault.yml"
    fi

    if [[ -z "$VAULT_SECRET" || "$VAULT_SECRET" == "__GENERATE_VAULT_SECRET__" ]]; then
        # Generate random secret - prefer openssl if available, fallback to urandom
        if command -v openssl &>/dev/null; then
            VAULT_SECRET="$(openssl rand -base64 64 | tr -dc 'A-Za-z0-9' | head -c 60)"
        else
            # LC_ALL=C needed for macOS compatibility with tr
            VAULT_SECRET="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 60)"
        fi
    fi

    if [[ -z "$VAULT_CONTENT" || "$VAULT_CONTENT" == "__GENERATE_VAULT_CONTENT__" ]]; then
        VAULT_CONTENT="$SETUP_DIR/vault_template.j2"
    fi

    if [[ -z "$VAULT_MAIL" || "$VAULT_MAIL" == "__GENERATE_VAULT_MAIL__" ]]; then
        VAULT_MAIL="$USERNAME@"
    fi

    # System link
    if [[ -z "$SYSTEMLINK_PATH" || "$SYSTEMLINK_PATH" == "__GENERATE_SYSTEMLINK_PATH__" ]]; then
        SYSTEMLINK_PATH="/usr/sbin/SOT"
    fi
}
