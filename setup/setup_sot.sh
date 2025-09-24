#!/bin/bash

# Wrapper to maintain script name compatibility if needed.
# This file is a copy of the previous setup_devops_toolkit.sh with the same logic.

# Farben für die Ausgabe
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m' 
BLUE='\033[0;34m' 
PINK='\033[0;35m'
BOLD='\033[1m'
GREY='\033[1;90m'
NC='\033[0m' # Keine Farbe

############# PARAMETER VOR FLAGS ##############
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG_FILE="${SOT_DEFAULT_CONFIG:-$SCRIPT_DIR/../services/default_config.yml}"
DEFAULT_BRANCH_HINT="production"

ORIGINAL_ARGS=("$@")
for ((i = 0; i < ${#ORIGINAL_ARGS[@]}; i++)); do
    if [[ "${ORIGINAL_ARGS[$i]}" == "-config" ]]; then
        next_index=$((i + 1))
        if (( next_index < ${#ORIGINAL_ARGS[@]} )) && [[ -n "${ORIGINAL_ARGS[$next_index]}" && "${ORIGINAL_ARGS[$next_index]}" != -* ]]; then
            DEFAULT_CONFIG_FILE="${ORIGINAL_ARGS[$next_index]}"
        else
            echo -e "${RED}No configuration file specified with -config.${NC}"
            exit 1
        fi
        break
    fi
    if [[ "${ORIGINAL_ARGS[$i]}" == "-branch" ]]; then
        next_index=$((i + 1))
        if (( next_index < ${#ORIGINAL_ARGS[@]} )) && [[ -n "${ORIGINAL_ARGS[$next_index]}" && "${ORIGINAL_ARGS[$next_index]}" != -* ]]; then
            DEFAULT_BRANCH_HINT="${ORIGINAL_ARGS[$next_index]}"
        fi
    fi
done
set -- "${ORIGINAL_ARGS[@]}"

declare -A CONFIG_DEFAULTS

load_default_config() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        local tmp_file=""
        local source_url="${SOT_DEFAULT_CONFIG_URL:-https://raw.githubusercontent.com/NiklasJavier/SOT/${DEFAULT_BRANCH_HINT}/services/default_config.yml}"
        tmp_file="$(mktemp)"
        if curl -fsSL "$source_url" -o "$tmp_file"; then
            echo -e "${GREY}Default configuration not found locally. Downloaded from ${YELLOW}$source_url${NC}"
            file="$tmp_file"
            DEFAULT_CONFIG_FILE="$tmp_file"
        else
            echo -e "${RED}Default configuration missing: ${YELLOW}$1${NC}"
            echo -e "${RED}Additionally failed to download configuration from: ${YELLOW}$source_url${NC}"
            exit 1
        fi
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line%%$'\r'}"
        if [[ -z "${line//[[:space:]]/}" ]]; then
            continue
        fi

        if [[ "$line" =~ ^([a-zA-Z0-9_]+):[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            value="${value%\"}"
            value="${value#\"}"
            CONFIG_DEFAULTS["$key"]="$value"
        fi
    done < "$file"
}

apply_config_defaults() {
    for key in "${!CONFIG_DEFAULTS[@]}"; do
        local var_name="${key^^}"
        var_name="${var_name//-/_}"
        local value="${CONFIG_DEFAULTS[$key]}"
        printf -v "$var_name" '%s' "$value"
    done
}

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

    declare -A seen_tools=()
    local normalized=""
    for token in $TOOLS; do
        [[ -z "$token" ]] && continue
        if [[ -n "${seen_tools[$token]:-}" ]]; then
            continue
        fi
        seen_tools[$token]=1
        if [[ -z "$normalized" ]]; then
            normalized="$token"
        else
            normalized+=" $token"
        fi
    done
    TOOLS="$normalized"
}

generate_dynamic_defaults() {
    if [[ -z "$USERNAME" || "$USERNAME" == "__GENERATE_USERNAME__" ]]; then
        USERNAME="$(< /dev/urandom tr -dc '[:upper:]' | head -c 11)"
    fi

    if [[ -z "$SYSTEM_NAME" || "$SYSTEM_NAME" == "__GENERATE_SYSTEM_NAME__" ]]; then
        SYSTEM_NAME="SRV-$USERNAME"
    fi

    if [[ -z "$CLONE_DIR" ]]; then
        CLONE_DIR="/etc/DevOpsToolkit"
    fi

    SETUP_DIR="$CLONE_DIR/setup"
    CONFIG_DIR="$CLONE_DIR/config"
    CLI_WRAPPER_FILE="$SETUP_DIR/cli_wrapper.sh"

    if [[ -z "$MODULES_DIR" || "$MODULES_DIR" == "__GENERATE_MODULES_DIR__" ]]; then
        MODULES_DIR="$CLONE_DIR/modules"
    fi

    if [[ -z "$SCRIPTS_DIR" || "$SCRIPTS_DIR" == "__GENERATE_SCRIPTS_DIR__" ]]; then
        SCRIPTS_DIR="$CLONE_DIR/scripts"
    fi

    if [[ -z "$PIPELINES_DIR" || "$PIPELINES_DIR" == "__GENERATE_PIPELINES_DIR__" ]]; then
        PIPELINES_DIR="$CLONE_DIR/pipelines"
    fi

    if [[ -z "$ANSIBLE_LOCAL_DIR" || "$ANSIBLE_LOCAL_DIR" == "__GENERATE_ANSIBLE_LOCAL_DIR__" ]]; then
        ANSIBLE_LOCAL_DIR="$MODULES_DIR/ansible"
    fi

    if [[ -z "$OVERRIDES_DIR" || "$OVERRIDES_DIR" == "__GENERATE_OVERRIDES_DIR__" ]]; then
        OVERRIDES_DIR="$CLONE_DIR/services/overrides"
    fi

    if [[ -z "$ANSIBLE_LOCAL_ENABLED" ]]; then
        ANSIBLE_LOCAL_ENABLED="true"
    fi

    if [[ -z "$ANSIBLE_LOCAL_PRIORITY" ]]; then
        ANSIBLE_LOCAL_PRIORITY="true"
    fi

    if [[ -z "$OPT_DATA_DIR" || "$OPT_DATA_DIR" == "__GENERATE_OPT_DATA_DIR__" ]]; then
        OPT_DATA_DIR="/opt/$SYSTEM_NAME"
    fi

    if [[ -z "$RUNNER_WORK_DIR" || "$RUNNER_WORK_DIR" == "__GENERATE_RUNNER_WORK_DIR__" ]]; then
        RUNNER_WORK_DIR="$OPT_DATA_DIR/runner"
    fi

    if [[ -z "$RUNNER_LOG_DIR" || "$RUNNER_LOG_DIR" == "__GENERATE_RUNNER_LOG_DIR__" ]]; then
        RUNNER_LOG_DIR="$RUNNER_WORK_DIR/logs"
    fi

    if [[ -z "$RUNNER_DEFAULT_MODE" ]]; then
        RUNNER_DEFAULT_MODE="aat"
    fi

    if [[ -z "$RUNNER_SYNC_BEFORE_RUN" ]]; then
        RUNNER_SYNC_BEFORE_RUN="true"
    fi

    if [[ -z "$AAT_BRANCH" ]]; then
        AAT_BRANCH="main"
    fi

    if [[ -z "$TID_BRANCH" ]]; then
        TID_BRANCH="main"
    fi

    if [[ -z "$RUNNER_ENABLED" ]]; then
        RUNNER_ENABLED="true"
    fi

    if [[ -z "$VAULT_FILE" || "$VAULT_FILE" == "__GENERATE_VAULT_FILE__" ]]; then
        VAULT_FILE="$OPT_DATA_DIR/vault.yml"
    fi

    if [[ -z "$VAULT_SECRET" || "$VAULT_SECRET" == "__GENERATE_VAULT_SECRET__" ]]; then
        VAULT_SECRET="$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 60)"
    fi

    if [[ -z "$VAULT_CONTENT" || "$VAULT_CONTENT" == "__GENERATE_VAULT_CONTENT__" ]]; then
        VAULT_CONTENT="$SETUP_DIR/vault_template.j2"
    fi

    if [[ -z "$VAULT_MAIL" || "$VAULT_MAIL" == "__GENERATE_VAULT_MAIL__" ]]; then
        VAULT_MAIL="$USERNAME@"
    fi

    if [[ -z "$SYSTEMLINK_PATH" || "$SYSTEMLINK_PATH" == "__GENERATE_SYSTEMLINK_PATH__" ]]; then
        SYSTEMLINK_PATH="/usr/sbin/SOT"
    fi
}

load_default_config "$DEFAULT_CONFIG_FILE"
apply_config_defaults

REPO_URL="https://github.com/NiklasJavier/DevOpsToolkit.git" # Name des Repositories
BRANCH="" # Variable zur Speicherung des Branch-Namens
BRANCH_DIR="" # Variable zur Speicherung des Branch-Verzeichnisses wird dynamisch festgelegt

AVAILABLE_TOOLS="" # optional: Liste der verfügbaren Tools

############# ANFANG DER PARAMETER FLAGS #############
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -branch)
      shift
      if [[ -z "${1:-}" || "$1" == -* ]]; then
        echo -e "${RED}No branch specified with -branch.${NC}"
        exit 1
      fi

      USE_DEFAULTS=true # Immer mit Standardwerten arbeiten
      BRANCH="$1"
      DEFAULT_BRANCH_HINT="$1"
      ;;
    -full) 
      shift
      if [[ "$1" == "true" || "$1" == "false" ]]; then
        FULL="$1"
      else
        echo -e "${RED}Invalid value for FULL. Please use 'true' or 'false'.${NC}"
        exit 1
      fi
      ;;
    -systemname) 
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        SYSTEM_NAME="$1"
      else
        echo -e "${RED}No systemname specified with -systemname.${NC}"
        exit 1
      fi
      ;;
    -username) 
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        USERNAME="$1"
      else
        echo -e "${RED}No username specified with -username.${NC}"
        exit 1
      fi
      ;;
    -key)
      shift
      SSH_KEY_FUNCTION_ENABLED=true  # SSH-Key-Funktion aktivieren
      if [[ -n "$1" && "$1" != -* ]]; then
        SSH_KEY_PUBLIC="$1"
      else
        SSH_KEY_FUNCTION_ENABLED=false
        SSH_KEY_PUBLIC=""  # Wenn leer, setze einen Standard-Schlüssel oder handle es entsprechend
      fi
      ;;
    -port)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        SSH_PORT="$1"
      else
        echo -e "${RED}No port specified with -port.${NC}"
        exit 1
      fi
      ;;
    -tools)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        TOOLS+=" $1 "
      else
        echo -e "${RED}No tools specified with -tools.${NC}"
        exit 1
      fi
      ;;
    -aat_url)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        AAT_REPO_URL="$1"
      else
        echo -e "${RED}No AAT repo URL specified with -aat_url.${NC}"
        exit 1
      fi
      ;;
    -aat_dir)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        AAT_DIR="$1"
      else
        echo -e "${RED}No AAT directory specified with -aat_dir.${NC}"
        exit 1
      fi
      ;;
    -aat_enabled)
      shift
      if [[ "$1" == "true" || "$1" == "false" ]]; then
        AAT_ENABLED="$1"
      else
        echo -e "${RED}Invalid value for aat_enabled. Please use 'true' or 'false'.${NC}"
        exit 1
      fi
      ;;
    -tid_url)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        TID_REPO_URL="$1"
      else
        echo -e "${RED}No TID repo URL specified with -tid_url.${NC}"
        exit 1
      fi
      ;;
    -tid_dir)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        TID_DIR="$1"
      else
        echo -e "${RED}No TID directory specified with -tid_dir.${NC}"
        exit 1
      fi
      ;;
    -tid_enabled)
      shift
      if [[ "$1" == "true" || "$1" == "false" ]]; then
        TID_ENABLED="$1"
      else
        echo -e "${RED}Invalid value for tid_enabled. Please use 'true' or 'false'.${NC}"
        exit 1
      fi
      ;;
    -local_ansible_enabled)
      shift
      if [[ "$1" == "true" || "$1" == "false" ]]; then
        ANSIBLE_LOCAL_ENABLED="$1"
      else
        echo -e "${RED}Invalid value for local_ansible_enabled. Please use 'true' or 'false'.${NC}"
        exit 1
      fi
      ;;
    -local_ansible_priority)
      shift
      if [[ "$1" == "true" || "$1" == "false" ]]; then
        ANSIBLE_LOCAL_PRIORITY="$1"
      else
        echo -e "${RED}Invalid value for local_ansible_priority. Please use 'true' or 'false'.${NC}"
        exit 1
      fi
      ;;
    -local_ansible_dir)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        ANSIBLE_LOCAL_DIR="$1"
      else
        echo -e "${RED}No directory specified with -local_ansible_dir.${NC}"
        exit 1
      fi
      ;;
    -overrides_dir)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        OVERRIDES_DIR="$1"
      else
        echo -e "${RED}No directory specified with -overrides_dir.${NC}"
        exit 1
      fi
      ;;
    -aat_branch)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        AAT_BRANCH="$1"
      else
        echo -e "${RED}No branch specified with -aat_branch.${NC}"
        exit 1
      fi
      ;;
    -tid_branch)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        TID_BRANCH="$1"
      else
        echo -e "${RED}No branch specified with -tid_branch.${NC}"
        exit 1
      fi
      ;;
    -runner_enabled)
      shift
      if [[ "$1" == "true" || "$1" == "false" ]]; then
        RUNNER_ENABLED="$1"
      else
        echo -e "${RED}Invalid value for runner_enabled. Please use 'true' or 'false'.${NC}"
        exit 1
      fi
      ;;
    -runner_mode)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        RUNNER_DEFAULT_MODE="$1"
      else
        echo -e "${RED}No mode specified with -runner_mode.${NC}"
        exit 1
      fi
      ;;
    -runner_sync)
      shift
      if [[ "$1" == "true" || "$1" == "false" ]]; then
        RUNNER_SYNC_BEFORE_RUN="$1"
      else
        echo -e "${RED}Invalid value for -runner_sync. Use 'true' or 'false'.${NC}"
        exit 1
      fi
      ;;
    -runner_work_dir)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        RUNNER_WORK_DIR="$1"
      else
        echo -e "${RED}No directory specified with -runner_work_dir.${NC}"
        exit 1
      fi
      ;;
    -runner_log_dir)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        RUNNER_LOG_DIR="$1"
      else
        echo -e "${RED}No directory specified with -runner_log_dir.${NC}"
        exit 1
      fi
      ;;
    -runner_inventory)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        RUNNER_DEFAULT_INVENTORY="$1"
      else
        echo -e "${RED}No path specified with -runner_inventory.${NC}"
        exit 1
      fi
      ;;
    -runner_aat_playbooks)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        RUNNER_AAT_PLAYBOOK_DIR="$1"
      else
        echo -e "${RED}No folder specified with -runner_aat_playbooks.${NC}"
        exit 1
      fi
      ;;
    -runner_tid_stack)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        RUNNER_TID_STACK_DIR="$1"
      else
        echo -e "${RED}No folder specified with -runner_tid_stack.${NC}"
        exit 1
      fi
      ;;
    -config)
      shift
      if [[ -n "$1" && "$1" != -* ]]; then
        DEFAULT_CONFIG_FILE="$1"
      else
        echo -e "${RED}No configuration file specified with -config.${NC}"
        exit 1
      fi
      ;;
    *)
      echo -e "${RED}Invalid option: $1${NC}" >&2
      exit 1
      ;;
  esac
  shift
done

ensure_sdkman_default

############# BRANCH FLAGS WENN NULL ############
if [ -z "$BRANCH" ]; then
      USE_DEFAULTS=true # Immer mit Standardwerten arbeiten
      BRANCH="production"
fi

# Recalculate dependent defaults in case CLI flags adjusted key values.
generate_dynamic_defaults

############# PARAMETER NACH FLAGS ##############
BRANCH_DIR="$SETUP_DIR/$BRANCH" # Branch-Verzeichnis festlegen
SETTINGS_DIR="$BRANCH_DIR/.settings" # Einstellungsverzeichnis festlegen
CONFIG_FILE="$SETTINGS_DIR/config.yaml" # Konfigurationsdatei festlegen

checkSettingsDirExist() {
    if [ -d "$SETTINGS_DIR" ]; then
        echo -e "${RED}Settings directory exists: ${YELLOW}$SETTINGS_DIR${NC}"
        echo -e "${RED}Please use ${YELLOW}'SOT debug update' ${RED}to apply the latest changes or ${YELLOW}'SOT debug delete' ${RED}to remove the current setup.${NC}"
        kill -INT $$
        else
        echo -e "${GREY}Settings directory does not exist: ${YELLOW}$SETTINGS_DIR${NC}"
    fi
}

startOverview() {
echo -e "${PINK}    ____            ____            "
echo -e "${PINK}   / __ \___ _   __/ __ \____  _____"
echo -e "${PINK}  / / / / _ \ | / / / / / __ \/ ___/"
echo -e "${PINK} / /_/ /  __/ |/ / /_/ / /_/ (__  ) "
echo -e "${PINK}/_____/\___/|___/\____/ .___/____/  "
echo -e "${PINK}                     /_/            "
echo -e "${PINK}                                    "
echo -e "${PINK}                                    "
# Debugging-Ausgabe (kann entfernt werden) 
echo -e "${GREY}Branch: ${YELLOW}$BRANCH ${NC}"
echo -e "${GREY}Full HostSetup: ${YELLOW}$FULL ${NC}"
echo -e "${GREY}Verwendete Tools: ${YELLOW}$TOOLS ${NC}"
echo -e "${GREY}Port: ${YELLOW}$SSH_PORT ${NC}"
echo -e "${GREY}Benutzername: ${YELLOW}$USERNAME ${NC}"
echo -e "${GREY}Systemname: ${YELLOW}$SYSTEM_NAME ${NC}"
echo -e "${GREY}SSH Key aktiviert: ${YELLOW}$SSH_KEY_FUNCTION_ENABLED ${NC}"
echo -e "${GREY}SSH Key Public: ${YELLOW}$SSH_KEY_PUBLIC ${NC}"
echo -e "${GREY}Branch-Verzeichnis: ${YELLOW}$BRANCH_DIR ${NC}"
echo -e "${GREY}Einstellungsverzeichnis: ${YELLOW}$SETTINGS_DIR ${NC}"
echo -e "${GREY}Konfigurationsdatei: ${YELLOW}$CONFIG_FILE ${NC}"
echo -e "${GREY}Skriptverzeichnis: ${YELLOW}$SCRIPTS_DIR ${NC}"
echo -e "${GREY}Pipeline-Verzeichnis: ${YELLOW}$PIPELINES_DIR ${NC}"
echo -e "${GREY}Systemlink: ${YELLOW}$SYSTEMLINK_PATH ${NC}"
### show AAT/TID
echo -e "${GREY}AAT URL: ${YELLOW}$AAT_REPO_URL ${NC}"
echo -e "${GREY}AAT DIR: ${YELLOW}$AAT_DIR ${NC}"
echo -e "${GREY}AAT Enabled: ${YELLOW}$AAT_ENABLED ${NC}"

echo -e "${GREY}TID URL: ${YELLOW}$TID_REPO_URL ${NC}"
echo -e "${GREY}TID DIR: ${YELLOW}$TID_DIR ${NC}"
echo -e "${GREY}TID Enabled: ${YELLOW}$TID_ENABLED ${NC}"

echo -e "${GREY}Runner Enabled: ${YELLOW}$RUNNER_ENABLED ${NC}"
echo -e "${GREY}Runner Default Mode: ${YELLOW}$RUNNER_DEFAULT_MODE ${NC}"
echo -e "${GREY}Runner Sync Before Run: ${YELLOW}$RUNNER_SYNC_BEFORE_RUN ${NC}"
echo -e "${GREY}Runner Workdir: ${YELLOW}$RUNNER_WORK_DIR ${NC}"
echo -e "${GREY}Runner Logdir: ${YELLOW}$RUNNER_LOG_DIR ${NC}"
}

checkRootPermissions() {
# Überprüfen, ob das Skript als Root ausgeführt wird
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root.${NC}"
    exit 1
    else
    echo -e "${GREY}Running as root...${NC}"
fi
}


copyAndSetTheRepository() {
# Überprüfen, ob Git installiert ist
if ! command -v git &> /dev/null; then
    echo -e "${RED}Git is not installed. Installing Git..."
    echo -e "${GREY}"
    sudo apt-get update
    sudo apt-get install -y git
    # Überprüfen, ob die Installation erfolgreich war
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Git installation failed. Aborting..."
        exit 1
    else
        echo -e "${GREY}Git installed successfully."
    fi
else
    echo -e "${GREY}Git is already installed."
fi
# Verzeichnis erstellen, wenn es nicht existiert
if [ ! -d "$CLONE_DIR" ]; then
    echo -e "${GREY}Creating directory $CLONE_DIR...${NC}"
    sudo mkdir -p "$CLONE_DIR"
fi
# Prüfen, ob das Repository bereits geklont wurde
if [ -d "$CLONE_DIR/.git" ]; then
    echo -e "${GREY}Repository already exists. Pulling latest changes..."
    cd "$CLONE_DIR" || exit
    sudo git pull
else
    echo -e "${GREY}Cloning the repository into $CLONE_DIR with branch $BRANCH..."
    sudo git clone -b "$BRANCH" --single-branch "$REPO_URL" "$CLONE_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to clone the repository. Aborting...${NC}"
        exit 1
    fi
fi
}

settingsEnvironmentFolder() {
# Prüfen, ob der branch-spezifische Ordner existiert, und erstellen, wenn nicht
if [ ! -d "$BRANCH_DIR" ]; then
    echo -e "${GREY}Creating branch-specific folder: $BRANCH_DIR...${NC}"
    mkdir -p "$BRANCH_DIR"
else
    echo -e "${GREY}Branch-specific folder already exists: $BRANCH_DIR...${NC}"
fi
# Prüfen, ob der .settings-Ordner existiert, und erstellen, wenn nicht
if [ ! -d "$SETTINGS_DIR" ]; then
    echo -e "${GREY}Creating .settings folder in $BRANCH_DIR...${NC}"
    mkdir -p "$SETTINGS_DIR"
else
    echo -e "${GREY}.settings folder already exists in $BRANCH_DIR...${NC}"
fi
# Ensure overrides directory exists for environment-specific settings
if [ ! -d "$OVERRIDES_DIR" ]; then
    echo -e "${GREY}Creating overrides directory at $OVERRIDES_DIR...${NC}"
    mkdir -p "$OVERRIDES_DIR"
fi
# Konfigurationsdatei erstellen
touch -f "$SETTINGS_DIR/config.yaml"
}

editCliWrapperFile() {
# Konfigurationsdatei für das Setup in devops_cli.sh einfügen
CLI_CONFIG_MODLINE="CONFIG_FILE="
CLI_CONFIG_MODLINE+="\"$CONFIG_FILE\""
sed -i "5i $CLI_CONFIG_MODLINE" "$CLI_WRAPPER_FILE"
echo -e "${GREY}Zeile wurde in $CLI_WRAPPER_FILE an Position 5 eingefügt.${NC}"
}

createCliWrapperSbinLink() {
  ensure_symlink() {
    local link_path="$1"

    if [ -L "$link_path" ]; then
      if [ "$(readlink "$link_path")" != "$CLI_WRAPPER_FILE" ]; then
        echo -e "${GREY}Symlink $link_path existiert und zeigt auf einen anderen Pfad. Aktualisierung...${NC}"
        sudo ln -sf "$CLI_WRAPPER_FILE" "$link_path"
      else
        echo -e "${GREY}Symlink $link_path existiert bereits und zeigt auf das richtige Ziel.${NC}"
      fi
    else
      echo -e "${GREY}Symlink $link_path existiert nicht. Erstellen...${NC}"
      sudo ln -s "$CLI_WRAPPER_FILE" "$link_path"
    fi
  }

  ensure_symlink "$SYSTEMLINK_PATH"

  local lowercase_link_dir
  local lowercase_link_path
  lowercase_link_dir="$(dirname "$SYSTEMLINK_PATH")"
  lowercase_link_path="${lowercase_link_dir}/$(basename "$SYSTEMLINK_PATH" | tr '[:upper:]' '[:lower:]')"

  if [ "$lowercase_link_path" != "$SYSTEMLINK_PATH" ]; then
    ensure_symlink "$lowercase_link_path"
  fi
  unset lowercase_link_dir lowercase_link_path
}

makeScriptExecutable() {
# Alle Skripte ausführbar machen
echo -e "${GREY}Making all scripts in $CLONE_DIR executable...${NC}"
sudo find "$CLONE_DIR" -type f -name "*.sh" -exec chmod +x {} \;
echo -e "${GREY}Setup completed! Repository cloned to $CLONE_DIR and scripts are now executable.${NC}"
}

cloneOrUpdateAAT() {
if [[ "$AAT_ENABLED" != true ]]; then
    echo -e "${GREY}AAT integration disabled. Skipping AAT clone/update.${NC}"
    return 0
fi

if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Warning: Git not installed; cannot manage AAT. Continuing...${NC}"
    return 0
fi

echo -e "${GREY}Ensuring AAT repository at ${YELLOW}$AAT_DIR${GREY} from ${YELLOW}$AAT_REPO_URL${GREY}...${NC}"
if [ -d "$AAT_DIR/.git" ]; then
    echo -e "${GREY}AAT repo exists. Pulling latest changes...${NC}"
    sudo git -C "$AAT_DIR" pull || echo -e "${YELLOW}Warning: Could not pull AAT. Continuing...${NC}"
else
    sudo mkdir -p "$AAT_DIR"
    sudo git clone "$AAT_REPO_URL" "$AAT_DIR" || echo -e "${YELLOW}Warning: Could not clone AAT. Continuing...${NC}"
fi
}

cloneOrUpdateTID() {
if [[ "$TID_ENABLED" != true ]]; then
    echo -e "${GREY}TID integration disabled. Skipping TID clone/update.${NC}"
    return 0
fi

if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Warning: Git not installed; cannot manage TID. Continuing...${NC}"
    return 0
fi

echo -e "${GREY}Ensuring TID repository at ${YELLOW}$TID_DIR${GREY} from ${YELLOW}$TID_REPO_URL${GREY}...${NC}"
if [ -d "$TID_DIR/.git" ]; then
    echo -e "${GREY}TID repo exists. Pulling latest changes...${NC}"
    sudo git -C "$TID_DIR" pull || echo -e "${YELLOW}Warning: Could not pull TID. Continuing...${NC}"
else
    sudo mkdir -p "$TID_DIR"
    sudo git clone "$TID_REPO_URL" "$TID_DIR" || echo -e "${YELLOW}Warning: Could not clone TID. Continuing...${NC}"
fi
}

#parameterChanges() {
# Überprüfen, ob der Benutzer die Standardwerte verwenden möchte
#}

writeConfigFile() {
# Konfiguration in config.yaml speichern
echo -e "${GREY}To $CONFIG_FILE...${NC}"

AAT_INVENTORY_PATH="${AAT_INVENTORY_PATH:-host.ini}"
AAT_INVENTORY_VARS="${AAT_INVENTORY_VARS:-ssh_port system_name}"
TID_INVENTORY_PATH="${TID_INVENTORY_PATH:-host.ini}"
TID_INVENTORY_VARS="${TID_INVENTORY_VARS:-ssh_port system_name}"

# Speichern der Konfiguration im neuen Schema
cat <<- EOL > "$CONFIG_FILE"
sot:
  branch: "$BRANCH"
  user:
    system_name: "$SYSTEM_NAME"
    username: "$USERNAME"
    ssh_port: "$SSH_PORT"
  logging:
    level: "$LOG_LEVEL"
    file: "$LOG_FILE"
  flags:
    use_defaults: "$USE_DEFAULTS"
  tools:
    list: "$TOOLS"
  ssh:
    key_function_enabled: "$SSH_KEY_FUNCTION_ENABLED"
    public_key: "$SSH_KEY_PUBLIC"
  paths:
    clone: "$CLONE_DIR"
    modules: "$MODULES_DIR"
    scripts: "$SCRIPTS_DIR"
    pipelines: "$PIPELINES_DIR"
    ansible_local: "$ANSIBLE_LOCAL_DIR"
    overrides: "$OVERRIDES_DIR"
    opt_data: "$OPT_DATA_DIR"
    systemlink: "$SYSTEMLINK_PATH"
  vault:
    file: "$VAULT_FILE"
    secret: "$VAULT_SECRET"
    content: "$VAULT_CONTENT"
    mail: "$VAULT_MAIL"
  ansible:
    local:
      enabled: "$ANSIBLE_LOCAL_ENABLED"
      priority: "$ANSIBLE_LOCAL_PRIORITY"
  runner:
    enabled: "$RUNNER_ENABLED"
    mode: "$RUNNER_DEFAULT_MODE"
    sync_before_run: "$RUNNER_SYNC_BEFORE_RUN"
    work_dir: "$RUNNER_WORK_DIR"
    log_dir: "$RUNNER_LOG_DIR"
    default_inventory: "$RUNNER_DEFAULT_INVENTORY"
    aat_playbook_dir: "$RUNNER_AAT_PLAYBOOK_DIR"
    tid_stack_dir: "$RUNNER_TID_STACK_DIR"
  aat:
    enabled: "$AAT_ENABLED"
    repo: "$AAT_REPO_URL"
    dir: "$AAT_DIR"
    branch: "$AAT_BRANCH"
    inventory:
      path: "$AAT_INVENTORY_PATH"
      vars: "$AAT_INVENTORY_VARS"
  tid:
    enabled: "$TID_ENABLED"
    repo: "$TID_REPO_URL"
    dir: "$TID_DIR"
    branch: "$TID_BRANCH"
    inventory:
      path: "$TID_INVENTORY_PATH"
      vars: "$TID_INVENTORY_VARS"
EOL
echo -e "${GREY}Configuration saved in $CONFIG_FILE.${NC}"
}

installAvailableTools() {
    # "install_tools.sh" liegt im geklonten Verzeichnis. Falls der Clone-Pfad
    # (z. B. /etc/DevOpsToolkit) nicht erreichbar ist, greifen wir auf das
    # Verzeichnis dieses Skriptes zurück. Dadurch funktioniert das Setup auch
    # in Entwicklungsumgebungen, in denen das Repository nicht nach
    # $CLONE_DIR gespiegelt wurde.
    local install_script=""

    if [ -f "$CLONE_DIR/setup/install_tools.sh" ]; then
        install_script="$CLONE_DIR/setup/install_tools.sh"
    elif [ -f "$SCRIPT_DIR/install_tools.sh" ]; then
        install_script="$SCRIPT_DIR/install_tools.sh"
    fi

    if [ -n "$install_script" ]; then
        echo -e "${GREY}Switching to $install_script${NC}"
        bash "$install_script" "$MODULES_DIR" "$TOOLS"

        # Weiter im Skript, nachdem install_tools.sh ausgeführt wurde
        echo -e "${GREY}Returned from install_tools.sh, continuing...${NC}"
    else
        echo -e "${RED}Error: install_tools.sh not found under $CLONE_DIR/setup or $SCRIPT_DIR.${NC}"
        exit 1
    fi
}

initalScriptOverview() {
echo -e "${GREY}The initialization of the repo was successful.${NC}"
echo -e "${GREY}The following parameters have been set, but can still be adjusted under ${YELLOW}$CONFIG_FILE${GREY}.${NC}"
echo -e "${GREY}Nutze Standardwerte: ${YELLOW}\"$USE_DEFAULTS\" ${GREY}tools: ${YELLOW}\"$TOOLS\"${NC}\n"

echo -e "${GREY}# system_name: System-/Servername (Standard: generiert) + username: Aktueller Benutzer${NC}"
echo -e "${GREY}system_name: ${YELLOW}\"$SYSTEM_NAME\" ${GREY}username: ${YELLOW}\"$USERNAME\"${NC}\n"

echo -e "${GREY}# ssh_port: SSH-Port (Standard: 282).${NC}"
echo -e "${GREY}ssh_port: ${YELLOW}\"$SSH_PORT\"${NC}\n"

echo -e "${GREY}# ssh_key_function_enabled: SSH-Key-Funktion aktiv (true/false).${NC}"
echo -e "${GREY}ssh_key_function_enabled: ${YELLOW}\"$SSH_KEY_FUNCTION_ENABLED\"${NC}"
echo -e "${GREY}ssh_key_public: ${YELLOW}\"$SSH_KEY_PUBLIC\"${NC}\n"

echo -e "${GREY}# Datenverzeichnisse:${NC}"
echo -e "${GREY}opt_data_dir: ${YELLOW}\"$OPT_DATA_DIR\"${NC}"
echo -e "${GREY}modules_dir: ${YELLOW}\"$MODULES_DIR\"${NC}"
echo -e "${GREY}scripts_dir: ${YELLOW}\"$SCRIPTS_DIR\"${NC}"
echo -e "${GREY}pipelines_dir: ${YELLOW}\"$PIPELINES_DIR\"${NC}\n"

echo -e "${GREY}# runner: orchestrierte Setups (AAT/TID)${NC}"
echo -e "${GREY}runner_enabled: ${YELLOW}\"$RUNNER_ENABLED\"${NC}"
echo -e "${GREY}runner_default_mode: ${YELLOW}\"$RUNNER_DEFAULT_MODE\"${NC}"
echo -e "${GREY}runner_sync_before_run: ${YELLOW}\"$RUNNER_SYNC_BEFORE_RUN\"${NC}"
echo -e "${GREY}runner_work_dir: ${YELLOW}\"$RUNNER_WORK_DIR\"${NC}"
echo -e "${GREY}runner_log_dir: ${YELLOW}\"$RUNNER_LOG_DIR\"${NC}\n"

echo -e "${GREY}# log_file: Pfad zur Logdatei + log_level: Log-Level${NC}"
echo -e "${GREY}log_file: ${YELLOW}\"$LOG_FILE\" ${GREY}log_level: ${YELLOW}\"$LOG_LEVEL\"${NC}\n"

echo -e "${GREY}*** Playbooks can be started via commands ***${NC}"
echo -e "${GREY}>>> To do this, use '${RED}SOT${GREY}' to see a list of all possible actions.${NC}\n"
}

methods=(
checkSettingsDirExist
startOverview
checkRootPermissions
copyAndSetTheRepository
settingsEnvironmentFolder
editCliWrapperFile
createCliWrapperSbinLink
makeScriptExecutable
#parameterChanges
cloneOrUpdateAAT
cloneOrUpdateTID
writeConfigFile
installAvailableTools
initalScriptOverview
)

show_loading() {
    local pid=$1
    local delay=0.01
    local spinstr="|/-\\"
    local nc='\033[0m'

    while kill -0 $pid 2>/dev/null; do
        for i in `seq 0 3`; do
            printf "\r ${PINK}[%c]${GREY} " "${spinstr:i:1}"
            sleep $delay
        done
    done
    printf "\r    \r"
}

for method in "${methods[@]}"; do
echo -e "\n${GREY}======= ${GREEN}Running: ${PINK}[$method] ${GREY}=======${NC}"
$method &
pid=$!
show_loading $pid
wait $pid  
done

echo -e "${GREY}All tasks completed!${NC}"
