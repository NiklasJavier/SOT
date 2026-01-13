#!/bin/bash

# Standardkonfigurationsdatei (kann angepasst werden)
# bspw. festgelegt VAR: CONFIG_FILE

set -euo pipefail

SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Load shared library
# shellcheck source=../lib/init.sh
source "$SCRIPT_ROOT/lib/init.sh"

CONFIG_FILE=${CONFIG_FILE:-"$SCRIPT_ROOT/services/default_config.yml"}

if [[ ! -f "$CONFIG_FILE" ]]; then
  err "Configuration file not found: $CONFIG_FILE"
  exit 1
fi

# Konfigurationsdatei laden mit shared YAML parser
parse_yaml_to_vars "$CONFIG_FILE"

if [[ -z "${modules_dir:-}" && -n "${tools_dir:-}" ]]; then
  modules_dir="$tools_dir"
fi

DEFAULT_ROOT="$SCRIPT_ROOT"

if [[ -z "${modules_dir:-}" || "$modules_dir" == "__GENERATE_MODULES_DIR__" ]]; then
  modules_dir="$DEFAULT_ROOT/modules"
fi

if [[ -z "${scripts_dir:-}" || "$scripts_dir" == "__GENERATE_SCRIPTS_DIR__" ]]; then
  scripts_dir="$DEFAULT_ROOT/scripts"
fi

if [[ -z "${clone_dir:-}" || "$clone_dir" == "__GENERATE_CLONE_DIR__" ]]; then
  clone_dir="$DEFAULT_ROOT"
fi

if [[ -z "${opt_data_dir:-}" || "$opt_data_dir" == "__GENERATE_OPT_DATA_DIR__" ]]; then
  opt_data_dir="$DEFAULT_ROOT/.sot-data"
  mkdir -p "$opt_data_dir"
fi

if [[ -z "${vault_file:-}" || "$vault_file" == "__GENERATE_VAULT_FILE__" ]]; then
  vault_file="$DEFAULT_ROOT/setup/vault_template.j2"
fi

if [[ -z "${vault_secret:-}" || "$vault_secret" == "__GENERATE_VAULT_SECRET__" ]]; then
  vault_secret="local-secret"
fi

if [[ -z "${username:-}" || "$username" == "__GENERATE_USERNAME__" ]]; then
  username="${USER:-sot-user}"
fi

if [[ -n "${log_file:-}" ]]; then
  if mkdir -p "$(dirname "$log_file")" 2>/dev/null && touch "$log_file" 2>/dev/null; then
    :
  else
    echo "Warnung: Konnte Logdatei nicht initialisieren ($log_file). Logging wird deaktiviert." >&2
    log_file=""
  fi
fi

log_command() {
  # Use shared helper (re-export for backwards compatibility)
  log_command "$@"
}

# Note: is_true is now provided by lib/helpers.sh

CLI_METADATA_ARGS=(
  "$modules_dir"
  "$CONFIG_FILE"
  "$username"
  "$vault_file"
  "$vault_secret"
  "$opt_data_dir"
  "$clone_dir"
  "${systemlink_path:-}"
  "${log_file:-}"
  "${branch:-}"
)

invoke_integration_runner() {
  local integration="$1"
  shift || true

  local enabled_var="${integration}_enabled"
  local dir_var="${integration}_dir"
  local branch_var="${integration}_branch"
  local inventory_path_var="${integration}_inventory_path"
  local inventory_vars_var="${integration}_inventory_vars"

  local repo_dir="${!dir_var:-}"
  local enabled_value="${!enabled_var:-true}"
  local branch_value="${!branch_var:-}"
  local inventory_path_value="${!inventory_path_var:-host.ini}"
  local inventory_vars_value="${!inventory_vars_var:-}"
  local sync_script="$SCRIPT_ROOT/scripts/integrations/${integration}_sync.sh"

  case "$integration" in
    aat)
      [[ -n "$repo_dir" && "$repo_dir" != "__GENERATE_AAT_DIR__" ]] || repo_dir="/opt/AAT"
      [[ -n "$branch_value" && "$branch_value" != "__GENERATE_AAT_BRANCH__" ]] || branch_value="main"
      ;;
    tid)
      [[ -n "$repo_dir" && "$repo_dir" != "__GENERATE_TID_DIR__" ]] || repo_dir="/opt/TID"
      [[ -n "$branch_value" && "$branch_value" != "__GENERATE_TID_BRANCH__" ]] || branch_value="main"
      ;;
    *)
      echo "Unsupported integration namespace '$integration'." >&2
      return 1
      ;;
  esac

  if ! is_true "$enabled_value"; then
    echo "${integration^^} integration is disabled in config.yaml." >&2
    return 1
  fi

  local runner_path="$repo_dir/runner.sh"
  local synced=false

  if [[ ! -x "$runner_path" || ! -d "$repo_dir" ]]; then
    if [[ -x "$sync_script" ]]; then
      echo "Synchronising ${integration^^} repository before execution..."
      local -a sync_args=("$sync_script")
      if [[ -n "$branch_value" ]]; then
        sync_args+=("--branch" "$branch_value")
      fi
      sync_args+=("${CLI_METADATA_ARGS[@]}")
      if ! "${sync_args[@]}"; then
        echo "Failed to synchronise ${integration^^} repository. Aborting." >&2
        return 1
      fi
      synced=true
    fi
  fi

  if [[ -f "$runner_path" && ! -x "$runner_path" ]]; then
    chmod +x "$runner_path" 2>/dev/null || true
  fi

  if [[ ! -x "$runner_path" ]]; then
    echo "runner.sh not found or not executable for ${integration^^} at $repo_dir." >&2
    echo "Please ensure the repository is synchronised (e.g. 'SOT integrations ${integration}_sync')." >&2
    return 1
  fi

  if $synced; then
    local validate_script="$SCRIPT_ROOT/scripts/integrations/validate_sync.sh"
    if [[ -x "$validate_script" && -f "$CONFIG_FILE" && "$CONFIG_FILE" == *"config.yaml" ]]; then
      "$validate_script" "$CONFIG_FILE" || echo "Warning: validate_sync reported issues." >&2
    fi
  fi

  export SOT_CONFIG_FILE="$CONFIG_FILE"
  export SOT_MODULES_DIR="$modules_dir"
  export SOT_SCRIPTS_DIR="$scripts_dir"
  export SOT_OPT_DATA_DIR="$opt_data_dir"
  export SOT_CLONE_DIR="$clone_dir"
  export SOT_USERNAME="$username"
  export SOT_BRANCH="${branch:-}"
  export SOT_LOG_FILE="${log_file:-}"
  export SOT_SSH_PORT="${ssh_port:-}"
  export SOT_SYSTEM_NAME="${system_name:-}"
  export SOT_INTEGRATION_NAME="$integration"

  local previous_ansible_inventory="${ANSIBLE_INVENTORY:-}"
  local temp_inventory=""
  local inventory_source=""

  if [[ -n "$inventory_path_value" ]]; then
    if [[ "$inventory_path_value" = /* ]]; then
      inventory_source="$inventory_path_value"
    else
      inventory_source="$repo_dir/$inventory_path_value"
    fi
  fi

  if [[ -f "$inventory_source" ]]; then
    temp_inventory=$(mktemp "${TMPDIR:-/tmp}/sot_${integration}_inventory_XXXXXX")
    cp "$inventory_source" "$temp_inventory"

    local appended_vars=false
    local sanitized_vars="${inventory_vars_value//,/ }"
    for var_name in $sanitized_vars; do
      [[ -z "$var_name" ]] && continue
      local config_key="${var_name//-/_}"
      local var_value="${!config_key:-}"
      if [[ -n "$var_value" ]]; then
        if [[ $appended_vars == false ]]; then
          printf '\n[all:vars]\n' >> "$temp_inventory"
          appended_vars=true
        fi
        printf '%s=%s\n' "$var_name" "$var_value" >> "$temp_inventory"
      fi
    done

    if [[ -n "$temp_inventory" ]]; then
      export ANSIBLE_INVENTORY="$temp_inventory"
    fi
  fi

  local -a runner_cmd=("$runner_path")
  local -a log_args=("$integration")

  if [[ $# -gt 0 ]]; then
    if [[ "$1" == "help" ]]; then
      shift || true
      runner_cmd+=("--help")
      log_args+=("help")
      if [[ $# -gt 0 ]]; then
        runner_cmd+=("$@")
        log_args+=("$@")
      fi
    else
      runner_cmd+=("$@")
      log_args+=("$@")
    fi
  else
    runner_cmd+=("--help")
    log_args+=("--help")
  fi

  log_command "${log_args[*]}"
  local result=0
  if ! "${runner_cmd[@]}"; then
    result=$?
  fi

  if [[ -n "$temp_inventory" ]]; then
    rm -f "$temp_inventory"
    if [[ -n "$previous_ansible_inventory" ]]; then
      export ANSIBLE_INVENTORY="$previous_ansible_inventory"
    else
      unset ANSIBLE_INVENTORY
    fi
  fi

  return "$result"
}

show_help() {
  echo "Usage: SOT [foldername] <command> [args]"
  echo ""
  echo "Available commands:"

  if [[ ! -d "$scripts_dir" ]]; then
    echo "  (Keine Skripte gefunden - scripts_dir: $scripts_dir)"
  else
    find "$scripts_dir" -maxdepth 3 -type f -name "*.sh" -print0 | while IFS= read -r -d '' script; do
      rel_path="${script#"$scripts_dir/"}"
      rel_path="${rel_path%.sh}"
      echo "$rel_path" | tr '/' ' '
    done | sort
  fi

  echo ""
  echo "Use 'SOT help <command>' for more information on a specific command."
}

show_command_help() {
  local command_path="$1"

  if [[ -f "$command_path" ]] && grep -q '^##' "$command_path"; then
    awk '/^##/{sub(/^##[[:space:]]*/, ""); print}' "$command_path"
    return 0
  fi

  echo "No help available for this command."
  return 0
}

resolve_command_path() {
  local -n _resolved_path=$1
  local -n _consumed_args=$2
  shift 2
  local args=("$@")

  _resolved_path=""
  _consumed_args=0

  for ((i = ${#args[@]}; i > 0; i--)); do
    local parts=("${args[@]:0:i}")
    local joined="${parts[0]}"
    for part in "${parts[@]:1}"; do
      joined="$joined/$part"
    done

    local candidate="$scripts_dir/$joined.sh"
    if [[ -f "$candidate" ]]; then
      _resolved_path="$candidate"
      _consumed_args=$i
      return 0
    fi
  done

  return 1
}

execute_command() {
  local command_path="$1"
  shift

  if [[ -x "$command_path" ]]; then
    "$command_path" "$@" "$modules_dir" "$CONFIG_FILE" "$username" "$vault_file" "$vault_secret" "$opt_data_dir" "$clone_dir" "$systemlink_path" "$log_file" "$branch"
    return $?
  fi

  return 1
}

if [[ $# -eq 0 ]]; then
  echo "No command provided."
  show_help
  exit 1
fi

if [[ $1 == "help" ]]; then
  if [[ $# -eq 1 ]]; then
    show_help
    exit 0
  fi

  command_args=("${@:2}")
  if resolve_command_path COMMAND_PATH consumed "${command_args[@]}"; then
    show_command_help "$COMMAND_PATH"
  else
    echo "No help available for the command '${command_args[*]}'."
    exit 1
  fi
  exit 0
fi

case "$1" in
  aat|tid)
    integration="$1"
    shift
    if invoke_integration_runner "$integration" "$@"; then
      exit 0
    else
      exit $?
    fi
    ;;
esac

command_args=("$@")
if resolve_command_path COMMAND_PATH consumed "${command_args[@]}"; then
  set -- "${command_args[@]:$consumed}"
else
  COMMAND_PATH=""
fi

log_command "$COMMAND_PATH $*"

if [[ -n "$COMMAND_PATH" ]]; then
  if execute_command "$COMMAND_PATH" "$@"; then
    exit 0
  fi
  RESULT=$?
else
  RESULT=127
fi

echo "Error: Command not found."
show_help
printf 'The command failed with exit code %s.\n' "$RESULT"
exit "$RESULT"
