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

modules_dir="${META_ARGS[0]}"
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

lower_branch="${branch,,}"

if [[ -z "$RUNNER_AAT_PLAYBOOK_DIR" || "$RUNNER_AAT_PLAYBOOK_DIR" == "." ]]; then
  if [[ -d "$AAT_DIR/playbooks" ]]; then
    RUNNER_AAT_PLAYBOOK_DIR="playbooks"
  elif [[ -d "$AAT_DIR/ansible/playbooks" ]]; then
    RUNNER_AAT_PLAYBOOK_DIR="ansible/playbooks"
  fi
fi

detect_inventory_candidate() {
  local env_candidate="$1"
  local -a inventory_candidates=(
    "$AAT_DIR/inventory/$env_candidate/hosts.yml"
    "$AAT_DIR/inventory/$env_candidate/hosts.yaml"
    "$AAT_DIR/inventory/$env_candidate.yml"
    "$AAT_DIR/inventory/$env_candidate.yaml"
    "$AAT_DIR/inventory/${env_candidate}_hosts.yml"
    "$AAT_DIR/inventory/${env_candidate}_hosts.yaml"
  )
  for candidate in "${inventory_candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

if [[ -z "$RUNNER_DEFAULT_INVENTORY" ]]; then
  if inventory_path=$(detect_inventory_candidate "$lower_branch"); then
    RUNNER_DEFAULT_INVENTORY="$inventory_path"
  elif inventory_path=$(detect_inventory_candidate "production"); then
    RUNNER_DEFAULT_INVENTORY="$inventory_path"
  fi
fi

if [[ -z "$RUNNER_TID_STACK_DIR" || "$RUNNER_TID_STACK_DIR" == "." ]]; then
  if [[ -d "$TID_DIR/services" ]]; then
    RUNNER_TID_STACK_DIR="services"
  elif [[ -d "$TID_DIR/modules" ]]; then
    RUNNER_TID_STACK_DIR="modules"
  fi
fi

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
      bash "$clone_dir/scripts/integrations/aat_sync.sh" "$config_file"
      ;;
    tid)
      if ! is_true "$TID_ENABLED"; then
        echo "TID-Integration ist deaktiviert und kann nicht synchronisiert werden." >&2
        return 1
      fi
      bash "$clone_dir/scripts/integrations/tid_sync.sh" "$config_file"
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

resolve_playbook_path() {
  local playbook_input="$1"
  if [[ "$playbook_input" == /* && -f "$playbook_input" ]]; then
    echo "$playbook_input"
    return 0
  fi

  local -a candidates=()
  if [[ "$playbook_input" == *.yml || "$playbook_input" == *.yaml ]]; then
    candidates+=("$AAT_DIR/$playbook_input")
    if [[ -n "$RUNNER_AAT_PLAYBOOK_DIR" ]]; then
      candidates+=("$AAT_DIR/$RUNNER_AAT_PLAYBOOK_DIR/$playbook_input")
    fi
  else
    if [[ -n "$RUNNER_AAT_PLAYBOOK_DIR" ]]; then
      candidates+=(
        "$AAT_DIR/$RUNNER_AAT_PLAYBOOK_DIR/$playbook_input.yml"
        "$AAT_DIR/$RUNNER_AAT_PLAYBOOK_DIR/$playbook_input.yaml"
        "$AAT_DIR/$RUNNER_AAT_PLAYBOOK_DIR/$playbook_input"
      )
    fi
    candidates+=(
      "$AAT_DIR/$playbook_input.yml"
      "$AAT_DIR/$playbook_input.yaml"
      "$AAT_DIR/$playbook_input"
    )
  fi

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

resolve_inventory_for_env() {
  local env_name="$1"
  if [[ -z "$env_name" ]]; then
    return 1
  fi
  env_name="${env_name,,}"
  if inventory_path=$(detect_inventory_candidate "$env_name"); then
    echo "$inventory_path"
    return 0
  fi
  local inventory_root="$AAT_DIR/inventory/$env_name"
  if [[ -d "$inventory_root" ]]; then
    if [[ -f "$inventory_root/hosts" ]]; then
      echo "$inventory_root/hosts"
      return 0
    fi
    if [[ -f "$inventory_root/hosts.ini" ]]; then
      echo "$inventory_root/hosts.ini"
      return 0
    fi
  fi
  return 1
}

list_playbooks() {
  local base_dir="$AAT_DIR"
  if [[ -n "$RUNNER_AAT_PLAYBOOK_DIR" ]]; then
    base_dir="$AAT_DIR/$RUNNER_AAT_PLAYBOOK_DIR"
  fi
  if [[ -d "$base_dir" ]]; then
    {
      find "$base_dir" -maxdepth 2 -type f -iname "*.yml"
      find "$base_dir" -maxdepth 2 -type f -iname "*.yaml"
    } 2>/dev/null | sed "s|^$AAT_DIR/||" | sort -u
  fi
}

list_inventories() {
  local inventory_root="$AAT_DIR/inventory"
  if [[ -d "$inventory_root" ]]; then
    {
      find "$inventory_root" -maxdepth 2 -type f -name "hosts"
      find "$inventory_root" -maxdepth 2 -type f -name "hosts.ini"
      find "$inventory_root" -maxdepth 2 -type f -name "hosts.yml"
      find "$inventory_root" -maxdepth 2 -type f -name "hosts.yaml"
    } 2>/dev/null | sed "s|^$AAT_DIR/||" | sort -u
  fi
}

resolve_terraform_target() {
  local target_input="$1"
  TERRAFORM_WORKDIR=""
  TERRAFORM_AUTOVAR=""

  if [[ -z "$target_input" ]]; then
    return 1
  fi

  if [[ "$target_input" == /* ]]; then
    if [[ -d "$target_input" ]]; then
      TERRAFORM_WORKDIR="$target_input"
      return 0
    elif [[ -f "$target_input" ]]; then
      TERRAFORM_WORKDIR="$(dirname "$target_input")"
      TERRAFORM_AUTOVAR="$target_input"
      return 0
    fi
  fi

  local maybe_file="$TID_DIR/$target_input"
  if [[ -d "$maybe_file" ]]; then
    TERRAFORM_WORKDIR="$maybe_file"
    return 0
  elif [[ -f "$maybe_file" ]]; then
    TERRAFORM_WORKDIR="$TID_DIR"
    TERRAFORM_AUTOVAR="$maybe_file"
    return 0
  fi

  local simple_name="$target_input"
  simple_name="${simple_name#/}"
  local -a search_roots=()
  if [[ -n "$RUNNER_TID_STACK_DIR" ]]; then
    search_roots+=("$RUNNER_TID_STACK_DIR")
  fi
  search_roots+=(services modules stacks env)

  for root_dir in "${search_roots[@]}"; do
    [[ -d "$TID_DIR/$root_dir" ]] || continue
    if [[ -d "$TID_DIR/$root_dir/$simple_name" ]]; then
      TERRAFORM_WORKDIR="$TID_DIR/$root_dir/$simple_name"
      return 0
    fi
    if [[ "$simple_name" != *.tfvars ]]; then
      if [[ -f "$TID_DIR/$root_dir/$simple_name.tfvars" ]]; then
        TERRAFORM_WORKDIR="$TID_DIR"
        TERRAFORM_AUTOVAR="$TID_DIR/$root_dir/$simple_name.tfvars"
        return 0
      fi
    fi
    if [[ -f "$TID_DIR/$root_dir/$simple_name" ]]; then
      case "$simple_name" in
        *.tfvars|*.tfvars.template)
          TERRAFORM_WORKDIR="$TID_DIR"
          TERRAFORM_AUTOVAR="$TID_DIR/$root_dir/$simple_name"
          return 0
          ;;
      esac
    fi
  done

  return 1
}

list_terraform_targets() {
  if [[ ! -d "$TID_DIR" ]]; then
    return
  fi
  local -a entries=()
  local dir
  for dir in services modules stacks env; do
    if [[ -d "$TID_DIR/$dir" ]]; then
      while IFS= read -r item; do
        entries+=("$item")
      done < <({
        find "$TID_DIR/$dir" -maxdepth 1 -mindepth 1 -type d
        find "$TID_DIR/$dir" -maxdepth 1 -mindepth 1 -type f -name "*.tfvars"
        find "$TID_DIR/$dir" -maxdepth 1 -mindepth 1 -type f -name "*.tfvars.template"
      } 2>/dev/null | sed "s|^$TID_DIR/||")
    fi
  done
  if [[ ${#entries[@]} -gt 0 ]]; then
    printf '%s\n' "${entries[@]}" | sort -u
  fi
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
    if is_true "$AAT_ENABLED"; then
      echo
      echo "  Verfügbare AAT-Playbooks:"
      if mapfile -t __runner_playbooks < <(list_playbooks); then
        if [[ ${#__runner_playbooks[@]} -eq 0 ]]; then
          echo "    <keine Playbooks gefunden>"
        else
          printf '    %s\n' "${__runner_playbooks[@]}"
        fi
      fi
      echo
      echo "  Verfügbare Inventories:"
      if mapfile -t __runner_inventories < <(list_inventories); then
        if [[ ${#__runner_inventories[@]} -eq 0 ]]; then
          echo "    <keine Inventories gefunden>"
        else
          printf '    %s\n' "${__runner_inventories[@]}"
        fi
      fi
      unset __runner_playbooks __runner_inventories
    fi
    if is_true "$TID_ENABLED"; then
      echo
      echo "  Terraform-Ziele:"
      if mapfile -t __runner_targets < <(list_terraform_targets); then
        if [[ ${#__runner_targets[@]} -eq 0 ]]; then
          echo "    <keine Ziele gefunden>"
        else
          printf '    %s\n' "${__runner_targets[@]}"
        fi
      fi
      unset __runner_targets
    fi
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
    environment=""

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
        --env|--environment)
          ((i+1<${#USER_ARGS[@]})) || { echo "--env benötigt einen Namen." >&2; exit 1; }
          environment="${USER_ARGS[$((i+1))]}"
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

    if [[ -n "$environment" ]]; then
      if inventory_candidate=$(resolve_inventory_for_env "$environment"); then
        inventory="$inventory_candidate"
      else
        echo "Konnte kein Inventory für Umgebung '$environment' finden." >&2
        exit 1
      fi
    elif [[ -z "$inventory" ]]; then
      if inventory_candidate=$(resolve_inventory_for_env "$lower_branch"); then
        inventory="$inventory_candidate"
      fi
    fi

    if [[ -n "$inventory" && ! -f "$inventory" ]]; then
      echo "Angegebene Inventory-Datei existiert nicht: $inventory" >&2
      exit 1
    fi

    if [[ -n "$inventory" ]]; then
      inventory="$(readlink -f "$inventory")"
    fi

    if ! playbook_path=$(resolve_playbook_path "$playbook"); then
      echo "Playbook '$playbook' wurde im AAT-Repository nicht gefunden." >&2
      exit 1
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
      if [[ -f "$var_file" ]]; then
        ansible_cmd+=("-e" "@$(readlink -f "$var_file")")
      else
        ansible_cmd+=("-e" "@$var_file")
      fi
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

    if ! resolve_terraform_target "$stack"; then
      echo "Terraform-Ziel '$stack' konnte nicht aufgelöst werden." >&2
      exit 1
    fi

    stack_path="$TERRAFORM_WORKDIR"
    auto_var_file="$TERRAFORM_AUTOVAR"

    if [[ -z "$stack_path" || ! -d "$stack_path" ]]; then
      echo "Terraform-Arbeitsverzeichnis ungültig: ${stack_path:-<leer>}" >&2
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
    if [[ -n "$auto_var_file" ]]; then
      found=false
      for existing in "${var_files[@]}"; do
        if [[ "$existing" == "$auto_var_file" ]]; then
          found=true
          break
        fi
      done
      if ! $found; then
        var_files+=("$auto_var_file")
      fi
    fi

    if [[ ${#var_files[@]} -gt 0 ]]; then
      resolved_var_files=()
      for file in "${var_files[@]}"; do
        if [[ -f "$file" ]]; then
          resolved_var_files+=("$(readlink -f "$file")")
        else
          resolved_var_files+=("$file")
        fi
      done
      var_files=("${resolved_var_files[@]}")
      unset resolved_var_files
    fi

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
