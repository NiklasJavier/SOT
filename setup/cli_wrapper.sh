#!/bin/bash

# Standardkonfigurationsdatei (kann angepasst werden)
# bspw. festgelegt VAR: CONFIG_FILE

set -euo pipefail

SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG_FILE=${CONFIG_FILE:-"$SCRIPT_ROOT/services/default_config.yml"}

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Configuration file not found: $CONFIG_FILE" >&2
  exit 1
fi

# Konfigurationsdatei laden, falls vorhanden
while IFS= read -r line; do
  line="${line%%#*}"
  line="${line%%$'\r'}"
  [[ -z "${line//[[:space:]]/}" ]] && continue

  # Nur Zeilen verarbeiten, die ein ":" enthalten
  if grep -q ':' <<<"$line"; then
    # Den Namen und den Wert extrahieren
    var_name=$(cut -d ':' -f 1 <<<"$line" | xargs | tr ' ' '_')
    var_value=$(cut -d ':' -f 2- <<<"$line" | xargs)

    # Entferne die Anführungszeichen, wenn sie vorhanden sind
    var_value=$(sed 's/^"\(.*\)"$/\1/' <<<"$var_value")

    # Die Variable setzen
    eval "$var_name=\"$var_value\""
  fi
done < "$CONFIG_FILE"

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
  [[ -z "${log_file:-}" ]] && return 0
  printf '%s - %s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${USER:-unknown}" "$*" >> "$log_file"
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
  if [[ -x "$command_path" ]]; then
    "$command_path" --help
  else
    echo "No help available for this command."
    return 0
  fi
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
