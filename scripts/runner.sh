#!/bin/bash

set -euo pipefail

APPENDED_ARGS_COUNT=10
if [[ $# -lt ${APPENDED_ARGS_COUNT} ]]; then
  echo "runner: expected CLI metadata arguments from SOT. Please invoke via 'SOT runner'." >&2
  exit 1
fi

# Split user provided args from metadata appended by the SOT CLI.
args=("$@")
USER_ARG_COUNT=$((${#args[@]} - APPENDED_ARGS_COUNT))
USER_ARGS=("${args[@]:0:${USER_ARG_COUNT}}")
META_ARGS=("${args[@]: -${APPENDED_ARGS_COUNT}}")

tools_dir="${META_ARGS[0]}"
config_file="${META_ARGS[1]}"
username="${META_ARGS[2]}"
vault_file="${META_ARGS[3]}"
vault_secret="${META_ARGS[4]}"
opt_data_dir="${META_ARGS[5]}"
clone_dir="${META_ARGS[6]}"
systemlink_path="${META_ARGS[7]}"
log_file="${META_ARGS[8]}"
branch="${META_ARGS[9]}"

usage() {
  cat <<'USAGE'
Usage: SOT runner <subcommand> [options]

Subcommands
  aat|ansible <playbook> [options]
      Führt ein Ansible-Playbook aus dem konfigurierten AAT-Repository aus.
      Optionen:
        --inventory <path>        Inventory-Datei (Standard aus config.yaml)
        --extra-var <key=value>   Zusätzliche Variablen (mehrfach möglich)
        --extra-vars-file <file>  Zusätzliche Variablendatei (mehrfach möglich)
        --tags <tags>             Nur ausgewählte Tags ausführen
        --skip-tags <tags>        Angegebene Tags überspringen
        --limit <pattern>         Host-Begrenzung
        --check                   Check-/Dry-Run-Modus
        --diff                    Diff-Ausgabe aktivieren
        --sync                    Führt vorab einen "SOT aat sync" aus

  tid|terraform <stack> [options]
      Führt Terraform im konfigurierten TID-Repository aus.
      Optionen:
        --action <plan|apply|destroy|refresh|output>
                                  Terraform-Aktion (Default: plan)
        --workspace <name>         Terraform-Workspace wählen/erstellen
        --var-file <file>          Zusätzliche Var-Datei (mehrfach möglich)
        --var <key=value>          Inline-Variablen (mehrfach möglich)
        --auto-approve             Automatische Bestätigung für apply/destroy
        --no-init                  Überspringt 'terraform init'
        --sync                     Führt vorab einen "SOT tid sync" aus

  list
      Zeigt aufgelöste Pfade und Runner-Status aus config.yaml.

  help
      Zeigt diese Hilfe an.
USAGE
}

is_true() {
  case "${1,,}" in
    true|1|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

if [[ ${#USER_ARGS[@]} -eq 0 ]]; then
  usage
  exit 0
fi

# Minimal YAML parser (key: value)
declare -A CFG
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="${line%%$'\r'}"
  [[ -z "${line//[[:space:]]/}" ]] && continue
  if [[ "$line" == *":"* ]]; then
    key=$(echo "$line" | cut -d ':' -f 1 | xargs)
    value=$(echo "$line" | cut -d ':' -f 2- | xargs)
    value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/')
    CFG[$key]="$value"
  fi
done < "$config_file"

get_cfg() {
  local key="$1"
  local default="$2"
  if [[ -n "${CFG[$key]:-}" ]]; then
    echo "${CFG[$key]}"
  else
    echo "$default"
  fi
}

AAT_ENABLED=$(get_cfg "aat_enabled" "true")
AAT_DIR=$(get_cfg "aat_dir" "/opt/AAT")
AAT_REPO_URL=$(get_cfg "aat_repo_url" "https://github.com/NiklasJavier/AAT.git")

TID_ENABLED=$(get_cfg "tid_enabled" "true")
TID_DIR=$(get_cfg "tid_dir" "/opt/TID")
TID_REPO_URL=$(get_cfg "tid_repo_url" "https://github.com/NiklasJavier/TID.git")

RUNNER_ENABLED=$(get_cfg "runner_enabled" "true")
RUNNER_DEFAULT_MODE=$(get_cfg "runner_default_mode" "aat")
RUNNER_SYNC_BEFORE_RUN=$(get_cfg "runner_sync_before_run" "true")
RUNNER_WORK_DIR=$(get_cfg "runner_work_dir" "")
RUNNER_LOG_DIR=$(get_cfg "runner_log_dir" "")
RUNNER_DEFAULT_INVENTORY=$(get_cfg "runner_default_inventory" "")
RUNNER_AAT_PLAYBOOK_DIR=$(get_cfg "runner_aat_playbook_dir" "")
RUNNER_TID_STACK_DIR=$(get_cfg "runner_tid_stack_dir" "")

if [[ -z "$RUNNER_WORK_DIR" || "$RUNNER_WORK_DIR" == "__GENERATE_RUNNER_WORK_DIR__" ]]; then
  RUNNER_WORK_DIR="$opt_data_dir/runner"
fi
if [[ -z "$RUNNER_LOG_DIR" || "$RUNNER_LOG_DIR" == "__GENERATE_RUNNER_LOG_DIR__" ]]; then
  RUNNER_LOG_DIR="$RUNNER_WORK_DIR/logs"
fi

mkdir -p "$RUNNER_WORK_DIR" "$RUNNER_LOG_DIR"

if ! is_true "$RUNNER_ENABLED"; then
  echo "Runner ist in config.yaml deaktiviert (runner_enabled != true)." >&2
  exit 1
fi

sync_repo() {
  local type="$1"
  case "$type" in
    aat)
      if ! is_true "$AAT_ENABLED"; then
        echo "AAT-Integration ist deaktiviert und kann nicht synchronisiert werden." >&2
        return 1
      fi
      bash "$clone_dir/scripts/aat/sync.sh" "$config_file"
      ;;
    tid)
      if ! is_true "$TID_ENABLED"; then
        echo "TID-Integration ist deaktiviert und kann nicht synchronisiert werden." >&2
        return 1
      fi
      bash "$clone_dir/scripts/tid/sync.sh" "$config_file"
      ;;
  esac
}

run_with_logging() {
  local log_path="$1"
  shift
  local -a cmd=("$@")
  {
    echo "[#] $(date '+%Y-%m-%d %H:%M:%S') :: ${cmd[*]}"
    "${cmd[@]}"
  } 2>&1 | tee -a "$log_path"
}

subcommand="${USER_ARGS[0]}"
if [[ "$subcommand" != "help" && "$subcommand" != "--help" && "$subcommand" != "-h" && "$subcommand" != "list" && "$subcommand" != "aat" && "$subcommand" != "ansible" && "$subcommand" != "tid" && "$subcommand" != "terraform" ]]; then
  if [[ -n "$RUNNER_DEFAULT_MODE" ]]; then
    USER_ARGS=("$RUNNER_DEFAULT_MODE" "${USER_ARGS[@]}")
    subcommand="${USER_ARGS[0]}"
  fi
fi
case "$subcommand" in
  help|--help|-h)
    usage
    exit 0
    ;;
  list)
    cat <<EOF
Runner-Status für Branch '$branch'
  Runner aktiviert:          $RUNNER_ENABLED
  Standardmodus:             $RUNNER_DEFAULT_MODE
  Sync vor Ausführung:       $RUNNER_SYNC_BEFORE_RUN
  Arbeitsverzeichnis:        $RUNNER_WORK_DIR
  Log-Verzeichnis:           $RUNNER_LOG_DIR
  AAT aktiviert:             $AAT_ENABLED
  AAT Verzeichnis:           $AAT_DIR
  AAT Repo:                  $AAT_REPO_URL
  TID aktiviert:             $TID_ENABLED
  TID Verzeichnis:           $TID_DIR
  TID Repo:                  $TID_REPO_URL
  Default Inventory:         ${RUNNER_DEFAULT_INVENTORY:-<nicht gesetzt>}
  AAT Playbook-Ordner:       ${RUNNER_AAT_PLAYBOOK_DIR:-<nicht gesetzt>}
  TID Stack-Ordner:          ${RUNNER_TID_STACK_DIR:-<nicht gesetzt>}
EOF
    exit 0
    ;;
  aat|ansible)
    if ! is_true "$AAT_ENABLED"; then
      echo "AAT-Integration ist deaktiviert. Aktivieren Sie sie über config.yaml." >&2
      exit 1
    fi
    USER_ARGS=("${USER_ARGS[@]:1}")
    if [[ ${#USER_ARGS[@]} -eq 0 ]]; then
      echo "Bitte geben Sie ein Playbook an." >&2
      usage
      exit 1
    fi
    playbook="${USER_ARGS[0]}"
    inventory="$RUNNER_DEFAULT_INVENTORY"
    extra_vars=()
    extra_var_files=()
    tags=""
    skip_tags=""
    limit=""
    check_mode=false
    diff_mode=false
    perform_sync=false

    for ((i=1; i<${#USER_ARGS[@]}; i++)); do
      arg="${USER_ARGS[$i]}"
      case "$arg" in
        --inventory)
          ((i+1<${#USER_ARGS[@]})) || { echo "--inventory benötigt einen Pfad." >&2; exit 1; }
          inventory="${USER_ARGS[$((i+1))]}"
          ((i++))
          ;;
        --extra-var)
          ((i+1<${#USER_ARGS[@]})) || { echo "--extra-var benötigt einen Wert." >&2; exit 1; }
          extra_vars+=("${USER_ARGS[$((i+1))]}")
          ((i++))
          ;;
        --extra-vars-file)
          ((i+1<${#USER_ARGS[@]})) || { echo "--extra-vars-file benötigt einen Pfad." >&2; exit 1; }
          extra_var_files+=("${USER_ARGS[$((i+1))]}")
          ((i++))
          ;;
        --tags)
          ((i+1<${#USER_ARGS[@]})) || { echo "--tags benötigt einen Wert." >&2; exit 1; }
          tags="${USER_ARGS[$((i+1))]}"
          ((i++))
          ;;
        --skip-tags)
          ((i+1<${#USER_ARGS[@]})) || { echo "--skip-tags benötigt einen Wert." >&2; exit 1; }
          skip_tags="${USER_ARGS[$((i+1))]}"
          ((i++))
          ;;
        --limit)
          ((i+1<${#USER_ARGS[@]})) || { echo "--limit benötigt einen Wert." >&2; exit 1; }
          limit="${USER_ARGS[$((i+1))]}"
          ((i++))
          ;;
        --check)
          check_mode=true
          ;;
        --diff)
          diff_mode=true
          ;;
        --sync)
          perform_sync=true
          ;;
        *)
          echo "Unbekannte Option für aat: $arg" >&2
          usage
          exit 1
          ;;
      esac
    done

    if $perform_sync || is_true "$RUNNER_SYNC_BEFORE_RUN"; then
      sync_repo aat
    fi

    if [[ -z "$inventory" ]] && [[ -n "$RUNNER_AAT_PLAYBOOK_DIR" ]]; then
      default_inventory_candidate="$AAT_DIR/$RUNNER_AAT_PLAYBOOK_DIR/hosts.yml"
      if [[ -f "$default_inventory_candidate" ]]; then
        inventory="$default_inventory_candidate"
      fi
    fi

    if [[ -n "$inventory" && ! -f "$inventory" ]]; then
      echo "Angegebene Inventory-Datei existiert nicht: $inventory" >&2
      exit 1
    fi

    playbook_path=""
    if [[ "$playbook" == /* ]]; then
      playbook_path="$playbook"
    else
      if [[ -n "$RUNNER_AAT_PLAYBOOK_DIR" && -f "$AAT_DIR/$RUNNER_AAT_PLAYBOOK_DIR/$playbook" ]]; then
        playbook_path="$AAT_DIR/$RUNNER_AAT_PLAYBOOK_DIR/$playbook"
      elif [[ -f "$AAT_DIR/$playbook" ]]; then
        playbook_path="$AAT_DIR/$playbook"
      else
        echo "Playbook '$playbook' wurde im AAT-Repository nicht gefunden." >&2
        exit 1
      fi
    fi

    log_path="$RUNNER_LOG_DIR/aat_$(date '+%Y%m%d_%H%M%S').log"
    ansible_cmd=("ansible-playbook" "$playbook_path" "-e" "@$config_file")
    if [[ -n "$inventory" ]]; then
      ansible_cmd+=("-i" "$inventory")
    fi
    for var in "${extra_vars[@]}"; do
      ansible_cmd+=("-e" "$var")
    done
    for var_file in "${extra_var_files[@]}"; do
      ansible_cmd+=("-e" "@$var_file")
    done
    if [[ -n "$tags" ]]; then
      ansible_cmd+=("--tags" "$tags")
    fi
    if [[ -n "$skip_tags" ]]; then
      ansible_cmd+=("--skip-tags" "$skip_tags")
    fi
    if [[ -n "$limit" ]]; then
      ansible_cmd+=("--limit" "$limit")
    fi
    $check_mode && ansible_cmd+=("--check")
    $diff_mode && ansible_cmd+=("--diff")

    run_with_logging "$log_path" "${ansible_cmd[@]}"
    exit 0
    ;;
  tid|terraform)
    if ! is_true "$TID_ENABLED"; then
      echo "TID-Integration ist deaktiviert. Aktivieren Sie sie über config.yaml." >&2
      exit 1
    fi
    USER_ARGS=("${USER_ARGS[@]:1}")
    if [[ ${#USER_ARGS[@]} -eq 0 ]]; then
      echo "Bitte geben Sie einen Stack- oder Modulpfad für Terraform an." >&2
      usage
      exit 1
    fi
    stack="${USER_ARGS[0]}"
    action="plan"
    workspace=""
    var_files=()
    inline_vars=()
    auto_approve=false
    perform_sync=false
    run_init=true

    for ((i=1; i<${#USER_ARGS[@]}; i++)); do
      arg="${USER_ARGS[$i]}"
      case "$arg" in
        --action)
          ((i+1<${#USER_ARGS[@]})) || { echo "--action benötigt einen Wert." >&2; exit 1; }
          action="${USER_ARGS[$((i+1))]}"
          ((i++))
          ;;
        --workspace)
          ((i+1<${#USER_ARGS[@]})) || { echo "--workspace benötigt einen Namen." >&2; exit 1; }
          workspace="${USER_ARGS[$((i+1))]}"
          ((i++))
          ;;
        --var-file)
          ((i+1<${#USER_ARGS[@]})) || { echo "--var-file benötigt einen Pfad." >&2; exit 1; }
          var_files+=("${USER_ARGS[$((i+1))]}")
          ((i++))
          ;;
        --var)
          ((i+1<${#USER_ARGS[@]})) || { echo "--var benötigt einen Wert." >&2; exit 1; }
          inline_vars+=("${USER_ARGS[$((i+1))]}")
          ((i++))
          ;;
        --auto-approve)
          auto_approve=true
          ;;
        --no-init)
          run_init=false
          ;;
        --sync)
          perform_sync=true
          ;;
        *)
          echo "Unbekannte Option für tid: $arg" >&2
          usage
          exit 1
          ;;
      esac
    done

    if $perform_sync || is_true "$RUNNER_SYNC_BEFORE_RUN"; then
      sync_repo tid
    fi

    stack_path="$stack"
    if [[ "$stack_path" != /* ]]; then
      if [[ -n "$RUNNER_TID_STACK_DIR" && -d "$TID_DIR/$RUNNER_TID_STACK_DIR/$stack" ]]; then
        stack_path="$TID_DIR/$RUNNER_TID_STACK_DIR/$stack"
      else
        stack_path="$TID_DIR/$stack"
      fi
    fi

    if [[ ! -d "$stack_path" ]]; then
      echo "Terraform-Verzeichnis nicht gefunden: $stack_path" >&2
      exit 1
    fi

    if ! command -v terraform >/dev/null 2>&1; then
      echo "Terraform ist nicht installiert oder nicht im PATH." >&2
      exit 1
    fi

    log_path="$RUNNER_LOG_DIR/tid_$(date '+%Y%m%d_%H%M%S').log"

    if $run_init; then
      run_with_logging "$log_path" terraform -chdir="$stack_path" init -input=false
    fi

    if [[ -n "$workspace" ]]; then
      if ! run_with_logging "$log_path" terraform -chdir="$stack_path" workspace select "$workspace"; then
        run_with_logging "$log_path" terraform -chdir="$stack_path" workspace new "$workspace"
        run_with_logging "$log_path" terraform -chdir="$stack_path" workspace select "$workspace"
      fi
    fi

    terraform_cmd=(terraform -chdir="$stack_path" "$action")
    case "$action" in
      plan|apply|destroy)
        terraform_cmd+=(-input=false)
        ;;
    esac
    for file in "${var_files[@]}"; do
      terraform_cmd+=("-var-file=$file")
    done
    for var in "${inline_vars[@]}"; do
      terraform_cmd+=("-var=$var")
    done
    if [[ "$action" == "apply" || "$action" == "destroy" ]]; then
      $auto_approve && terraform_cmd+=("-auto-approve")
    fi

    run_with_logging "$log_path" "${terraform_cmd[@]}"
    exit 0
    ;;
  *)
    echo "Unbekannter Runner-Subcommand: $subcommand" >&2
    usage
    exit 1
    ;;
esac
