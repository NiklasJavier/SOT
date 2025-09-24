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

SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG_LOADER="$SCRIPT_ROOT/setup/config_loader.py"

if [[ ! -x "$CONFIG_LOADER" ]]; then
  if [[ -f "$CONFIG_LOADER" ]]; then
    chmod +x "$CONFIG_LOADER" 2>/dev/null || true
  fi
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to parse the configuration file." >&2
  exit 1
fi

declare -A CFG
while IFS= read -r assignment; do
  [[ -z "$assignment" ]] && continue
  eval "$assignment"
done < <(python3 "$CONFIG_LOADER" "$config_file" --select \
  aat_enabled aat_dir aat_repo_url aat_branch aat_inventory_path aat_inventory_vars \
  tid_enabled tid_dir tid_repo_url tid_branch tid_inventory_path tid_inventory_vars \
  runner_enabled runner_default_mode runner_sync_before_run runner_work_dir runner_log_dir \
  runner_default_inventory runner_aat_playbook_dir runner_tid_stack_dir \
  ansible_local_enabled ansible_local_priority ansible_local_dir overrides_dir)

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

AAT_ENABLED="${aat_enabled:-true}"
AAT_DIR="${aat_dir:-/opt/AAT}"
AAT_REPO_URL="${aat_repo_url:-https://github.com/NiklasJavier/AAT.git}"
AAT_BRANCH="${aat_branch:-main}"
AAT_INVENTORY_PATH="${aat_inventory_path:-host.ini}"
AAT_INVENTORY_VARS="${aat_inventory_vars:-}"

TID_ENABLED="${tid_enabled:-true}"
TID_DIR="${tid_dir:-/opt/TID}"
TID_REPO_URL="${tid_repo_url:-https://github.com/NiklasJavier/TID.git}"
TID_BRANCH="${tid_branch:-main}"
TID_INVENTORY_PATH="${tid_inventory_path:-host.ini}"
TID_INVENTORY_VARS="${tid_inventory_vars:-}"

RUNNER_ENABLED="${runner_enabled:-true}"
RUNNER_DEFAULT_MODE="${runner_default_mode:-aat}"
RUNNER_SYNC_BEFORE_RUN="${runner_sync_before_run:-true}"
RUNNER_WORK_DIR="${runner_work_dir:-}"
RUNNER_LOG_DIR="${runner_log_dir:-}"
RUNNER_DEFAULT_INVENTORY="${runner_default_inventory:-}"
RUNNER_AAT_PLAYBOOK_DIR="${runner_aat_playbook_dir:-}"
RUNNER_TID_STACK_DIR="${runner_tid_stack_dir:-}"
ANSIBLE_LOCAL_ENABLED="${ansible_local_enabled:-true}"
ANSIBLE_LOCAL_PRIORITY="${ansible_local_priority:-true}"
ANSIBLE_LOCAL_DIR="${ansible_local_dir:-$modules_dir/ansible}"
OVERRIDES_DIR="${overrides_dir:-$clone_dir/services/overrides}"

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
  [[ -n "$env_candidate" ]] || return 1

  mapfile -t __inventory_roots < <(gather_inventory_roots)
  for root in "${__inventory_roots[@]}"; do
    local -a inventory_candidates=(
      "$root/$env_candidate/hosts.yml"
      "$root/$env_candidate/hosts.yaml"
      "$root/$env_candidate.yml"
      "$root/$env_candidate.yaml"
      "$root/${env_candidate}_hosts.yml"
      "$root/${env_candidate}_hosts.yaml"
    )
    for candidate in "${inventory_candidates[@]}"; do
      if [[ -f "$candidate" ]]; then
        echo "$candidate"
        return 0
      fi
    done
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
      bash "$clone_dir/scripts/aat/sync.sh" --branch "$AAT_BRANCH" "$config_file"
      ;;
    tid)
      if ! is_true "$TID_ENABLED"; then
        echo "TID-Integration ist deaktiviert und kann nicht synchronisiert werden." >&2
        return 1
      fi
      bash "$clone_dir/scripts/tid/sync.sh" --branch "$TID_BRANCH" "$config_file"
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

get_local_playbook_root() {
  if [[ -d "$ANSIBLE_LOCAL_DIR/playbooks" ]]; then
    echo "$ANSIBLE_LOCAL_DIR/playbooks"
  else
    echo "$ANSIBLE_LOCAL_DIR"
  fi
}

gather_playbook_bases() {
  declare -a ordered=()
  declare -a local_candidates=()
  declare -A seen=()

  if is_true "$ANSIBLE_LOCAL_ENABLED"; then
    local local_root
    local_root=$(get_local_playbook_root)
    local_candidates+=("$local_root")
  fi

  if is_true "$ANSIBLE_LOCAL_ENABLED" && is_true "$ANSIBLE_LOCAL_PRIORITY"; then
    for dir in "${local_candidates[@]}"; do
      ordered+=("$dir")
    done
  fi

  if is_true "$AAT_ENABLED"; then
    if [[ -n "$RUNNER_AAT_PLAYBOOK_DIR" ]]; then
      ordered+=("$AAT_DIR/$RUNNER_AAT_PLAYBOOK_DIR")
    fi
    ordered+=("$AAT_DIR")
  fi

  if is_true "$ANSIBLE_LOCAL_ENABLED" && ! is_true "$ANSIBLE_LOCAL_PRIORITY"; then
    for dir in "${local_candidates[@]}"; do
      ordered+=("$dir")
    done
  fi

  for dir in "${ordered[@]}"; do
    [[ -d "$dir" ]] || continue
    if [[ -z "${seen[$dir]:-}" ]]; then
      printf '%s\n' "$dir"
      seen[$dir]=1
    fi
  done
}

gather_inventory_roots() {
  declare -a ordered=()
  declare -a local_candidates=()
  declare -A seen=()

  if is_true "$ANSIBLE_LOCAL_ENABLED"; then
    local_candidates+=("$ANSIBLE_LOCAL_DIR/inventory")
  fi

  if is_true "$ANSIBLE_LOCAL_ENABLED" && is_true "$ANSIBLE_LOCAL_PRIORITY"; then
    for dir in "${local_candidates[@]}"; do
      ordered+=("$dir")
    done
  fi

  if is_true "$AAT_ENABLED"; then
    ordered+=("$AAT_DIR/inventory")
  fi

  if is_true "$ANSIBLE_LOCAL_ENABLED" && ! is_true "$ANSIBLE_LOCAL_PRIORITY"; then
    for dir in "${local_candidates[@]}"; do
      ordered+=("$dir")
    done
  fi

  for dir in "${ordered[@]}"; do
    [[ -d "$dir" ]] || continue
    if [[ -z "${seen[$dir]:-}" ]]; then
      printf '%s\n' "$dir"
      seen[$dir]=1
    fi
  done
}

resolve_playbook_path() {
  local playbook_input="$1"
  if [[ "$playbook_input" == /* && -f "$playbook_input" ]]; then
    echo "$playbook_input"
    return 0
  fi

  mapfile -t __playbook_bases < <(gather_playbook_bases)
  local -a candidates=()
  for base in "${__playbook_bases[@]}"; do
    if [[ "$playbook_input" == *.yml || "$playbook_input" == *.yaml ]]; then
      candidates+=("$base/$playbook_input")
    else
      candidates+=(
        "$base/$playbook_input.yml"
        "$base/$playbook_input.yaml"
        "$base/$playbook_input"
      )
    fi
  done

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
  mapfile -t __inventory_roots < <(gather_inventory_roots)
  for root in "${__inventory_roots[@]}"; do
    local inventory_root="$root/$env_name"
    if [[ -d "$inventory_root" ]]; then
      if [[ -f "$inventory_root/hosts" ]]; then
        echo "$inventory_root/hosts"
        return 0
      fi
      if [[ -f "$inventory_root/hosts.ini" ]]; then
        echo "$inventory_root/hosts.ini"
        return 0
      fi
      if [[ -f "$inventory_root/hosts.yml" ]]; then
        echo "$inventory_root/hosts.yml"
        return 0
      fi
      if [[ -f "$inventory_root/hosts.yaml" ]]; then
        echo "$inventory_root/hosts.yaml"
        return 0
      fi
    fi
  done
  return 1
}

list_playbooks() {
  mapfile -t __playbook_bases < <(gather_playbook_bases)
  declare -a entries=()
  for base in "${__playbook_bases[@]}"; do
    [[ -d "$base" ]] || continue
    local label="LOCAL"
    local root="$ANSIBLE_LOCAL_DIR"
    if [[ "$base" == "$AAT_DIR"* ]]; then
      label="AAT"
      root="$AAT_DIR"
    fi
    while IFS= read -r item; do
      local relative="$item"
      if [[ "$label" == "AAT" ]]; then
        relative="${item#"$AAT_DIR"/}"
      else
        relative="${item#"$ANSIBLE_LOCAL_DIR"/}"
      fi
      entries+=("$label:$relative")
    done < <({
      find "$base" -maxdepth 2 -type f -iname "*.yml"
      find "$base" -maxdepth 2 -type f -iname "*.yaml"
    } 2>/dev/null)
  done
  if [[ ${#entries[@]} -gt 0 ]]; then
    printf '%s\n' "${entries[@]}" | sort -u
  fi
}

list_inventories() {
  mapfile -t __inventory_roots < <(gather_inventory_roots)
  declare -a entries=()
  for root in "${__inventory_roots[@]}"; do
    [[ -d "$root" ]] || continue
    local label="LOCAL"
    if [[ "$root" == "$AAT_DIR"* ]]; then
      label="AAT"
    fi
    while IFS= read -r item; do
      local relative="$item"
      if [[ "$label" == "AAT" ]]; then
        relative="${item#"$AAT_DIR"/}"
      else
        relative="${item#"$ANSIBLE_LOCAL_DIR"/}"
      fi
      entries+=("$label:$relative")
    done < <({
      find "$root" -maxdepth 2 -type f -name "hosts"
      find "$root" -maxdepth 2 -type f -name "hosts.ini"
      find "$root" -maxdepth 2 -type f -name "hosts.yml"
      find "$root" -maxdepth 2 -type f -name "hosts.yaml"
    } 2>/dev/null)
  done
  if [[ ${#entries[@]} -gt 0 ]]; then
    printf '%s\n' "${entries[@]}" | sort -u
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
  Lokale Ansible aktiviert:  $ANSIBLE_LOCAL_ENABLED
  Lokale Priorität:          $ANSIBLE_LOCAL_PRIORITY
  Lokaler Playbook-Pfad:     $ANSIBLE_LOCAL_DIR
  Overrides-Verzeichnis:     ${OVERRIDES_DIR:-<nicht gesetzt>}
  AAT aktiviert:             $AAT_ENABLED
  AAT Verzeichnis:           $AAT_DIR
  AAT Repo:                  $AAT_REPO_URL
  AAT Branch:                $AAT_BRANCH
  TID aktiviert:             $TID_ENABLED
  TID Verzeichnis:           $TID_DIR
  TID Repo:                  $TID_REPO_URL
  TID Branch:                $TID_BRANCH
  Default Inventory:         ${RUNNER_DEFAULT_INVENTORY:-<nicht gesetzt>}
  AAT Playbook-Ordner:       ${RUNNER_AAT_PLAYBOOK_DIR:-<nicht gesetzt>}
  TID Stack-Ordner:          ${RUNNER_TID_STACK_DIR:-<nicht gesetzt>}
EOF
    echo
    echo "  Verfügbare Ansible-Playbooks:"
    if mapfile -t __runner_playbooks < <(list_playbooks); then
      if [[ ${#__runner_playbooks[@]} -eq 0 ]]; then
        echo "    <keine Playbooks gefunden>"
      else
        for entry in "${__runner_playbooks[@]}"; do
          case "$entry" in
            LOCAL:*) echo "    [LOCAL] ${entry#LOCAL:}" ;;
            AAT:*) echo "    [AAT] ${entry#AAT:}" ;;
            *) echo "    $entry" ;;
          esac
        done
      fi
    fi
    echo
    echo "  Verfügbare Inventories:"
    if mapfile -t __runner_inventories < <(list_inventories); then
      if [[ ${#__runner_inventories[@]} -eq 0 ]]; then
        echo "    <keine Inventories gefunden>"
      else
        for entry in "${__runner_inventories[@]}"; do
          case "$entry" in
            LOCAL:*) echo "    [LOCAL] ${entry#LOCAL:}" ;;
            AAT:*) echo "    [AAT] ${entry#AAT:}" ;;
            *) echo "    $entry" ;;
          esac
        done
      fi
    fi
    unset __runner_playbooks __runner_inventories
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
    if ! is_true "$AAT_ENABLED" && ! is_true "$ANSIBLE_LOCAL_ENABLED"; then
      echo "Keine Ansible-Quelle verfügbar. Aktivieren Sie lokale Playbooks oder die AAT-Integration." >&2
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
      if is_true "$AAT_ENABLED"; then
        sync_repo aat
      fi
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
      echo "Playbook '$playbook' wurde weder lokal noch im AAT-Repository gefunden." >&2
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
