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
REPO_URL="https://github.com/NiklasJavier/DevOpsToolkit.git" # Name des Repositories
BRANCH="" # Variable zur Speicherung des Branch-Namens
BRANCH_DIR="" # Variable zur Speicherung des Branch-Verzeichnisses wird dynamisch festgelegt

USE_DEFAULTS=false # Möchten immer mit default werten arbeiten (true) oder nicht (false) Bspw. true wenn -t dev angegeben wurde

USERNAME="$(< /dev/urandom tr -dc 'A-Z' | head -c 11)" # Benutzername (zufällig generiert)
SYSTEM_NAME="SRV-$USERNAME" # Systemname (ehemals Hostname)
SSH_PORT="282" # Port für SSH-Verbindung
SSH_KEY_FUNCTION_ENABLED=false # SSH-Key-Funktion aktivieren
SSH_KEY_PUBLIC="none" # Öffentlicher SSH-Schlüssel

CLONE_DIR="/etc/DevOpsToolkit"
ENV_DIR="$CLONE_DIR/environments"
TOOLS_DIR="$CLONE_DIR/tools"
SCRIPTS_DIR="$CLONE_DIR/scripts" 
PIPELINES_DIR="$CLONE_DIR/pipelines" 
OPT_DATA_DIR="/opt/$SYSTEM_NAME" # Datenverzeichnis, in dem Anwendungsdaten gespeichert werden

SETTINGS_DIR="" 
CONFIG_FILE="" # Konfigurationsdatei für das Setup in Settings-Verzeichnis
DEVOPS_CLI_FILE="$ENV_DIR/sot_cli.sh"

VAULT_FILE="$OPT_DATA_DIR/vault.yml" # Vault-Datei für sensible Daten (Ansible)
VAULT_SECRET="$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 60)" # Geheimer Schlüssel für die Vault-Datei
VAULT_CONTENT="$ENV_DIR/vault_content.j2" # Vorlage für den Inhalt der Vault-Datei
VAULT_MAIL="$USERNAME@" # E-Mail-Adresse für die Vault-Datei

SYSLINK_PATH="/usr/sbin/SOT" # Pfad für den Symlink
LOG_LEVEL="info" # Log-Level für die Protokollierung debug, info, warn, error
LOG_FILE="/var/log/devops_commands.log"

TOOLS="" # Liste der Tools, die installiert werden sollen
TOOLS+="ansible docker" # Standard-Tools, die installiert werden sollen
AVAILABLE_TOOLS="" # optional: Liste der verfügbaren Tools

# AAT (Ansible Automation Tools) Integration Defaults
AAT_REPO_URL="https://github.com/NiklasJavier/AAT.git"
AAT_DIR="/opt/AAT"
AAT_ENABLED=true

# TID (Terraform Infrastructure Deployment) Integration Defaults
TID_REPO_URL="https://github.com/NiklasJavier/TID.git"
TID_DIR="/opt/TID"
TID_ENABLED=true

############# ANFANG DER PARAMETER FLAGS #############
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -branch)
      shift
      case "$1" in
        production|staging|dev)
          USE_DEFAULTS=true # Immer mit Standardwerten arbeiten
          BRANCH="$1"
          ;;
        *)
          echo -e "${RED}Invalid branch specified with -t. Please use 'production', 'staging', or 'dev'.${NC}"
          exit 1
          ;;
      esac
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
    *)
      echo -e "${RED}Invalid option: $1${NC}" >&2
      exit 1
      ;;
  esac
  shift
done

############# BRANCH FLAGS WENN NULL ############
if [ -z "$BRANCH" ]; then
      USE_DEFAULTS=true # Immer mit Standardwerten arbeiten
      BRANCH="production"
fi

############# PARAMETER NACH FLAGS ##############
BRANCH_DIR="$ENV_DIR/$BRANCH" # Branch-Verzeichnis festlegen
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
echo -e "${GREY}Verwendete Tools: ${YELLOW}${TOOLS[*]} ${NC}"
echo -e "${GREY}Port: ${YELLOW}$PORT ${NC}"
echo -e "${GREY}Benutzername: ${YELLOW}$USERNAME ${NC}"
echo -e "${GREY}Systemname: ${YELLOW}$SYSTEM_NAME ${NC}"
echo -e "${GREY}SSH Key aktiviert: ${YELLOW}$SSH_KEY_FUNCTION_ENABLED ${NC}"
echo -e "${GREY}SSH Key Public: ${YELLOW}$SSH_KEY_PUBLIC ${NC}"
echo -e "${GREY}Branch-Verzeichnis: ${YELLOW}$BRANCH_DIR ${NC}"
echo -e "${GREY}Einstellungsverzeichnis: ${YELLOW}$SETTINGS_DIR ${NC}"
echo -e "${GREY}Konfigurationsdatei: ${YELLOW}$CONFIG_FILE ${NC}"
echo -e "${GREY}Skriptverzeichnis: ${YELLOW}$SCRIPTS_DIR ${NC}"
echo -e "${GREY}Pipeline-Verzeichnis: ${YELLOW}$PIPELINES_DIR ${NC}"
### show AAT/TID
echo -e "${GREY}AAT URL: ${YELLOW}$AAT_REPO_URL ${NC}"
echo -e "${GREY}AAT DIR: ${YELLOW}$AAT_DIR ${NC}"
echo -e "${GREY}AAT Enabled: ${YELLOW}$AAT_ENABLED ${NC}"

echo -e "${GREY}TID URL: ${YELLOW}$TID_REPO_URL ${NC}"
echo -e "${GREY}TID DIR: ${YELLOW}$TID_DIR ${NC}"
echo -e "${GREY}TID Enabled: ${YELLOW}$TID_ENABLED ${NC}"
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
    cd "$CLONE_DIR"
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
# Konfigurationsdatei erstellen
touch -f "$SETTINGS_DIR/config.yaml"
}

editCliWrapperFile() {
# Konfigurationsdatei für das Setup in devops_cli.sh einfügen
CLI_CONFIG_MODLINE="CONFIG_FILE="
CLI_CONFIG_MODLINE+="\"$CONFIG_FILE\""
sed -i "5i $CLI_CONFIG_MODLINE" "$DEVOPS_CLI_FILE"
echo -e "${GREY}Zeile wurde in $DEVOPS_CLI_FILE an Position 5 eingefügt.${NC}"
}

createCliWrapperSbinLink() {
# Überprüfen, ob der Symlink bereits existiert
if [ -L "$SYSLINK_PATH" ]; then
    # Wenn der Symlink existiert, überprüfen, ob er auf die richtige Datei zeigt
    if [ "$(readlink "$SYSLINK_PATH")" != "$DEVOPS_CLI_FILE" ]; then
        echo -e "${GREY}Symlink $SYSLINK_PATH existiert und zeigt auf einen anderen Pfad. Aktualisierung...${NC}"
        sudo ln -sf "$DEVOPS_CLI_FILE" "$SYSLINK_PATH"
    else
        echo -e "${GREY}Symlink $SYSLINK_PATH existiert bereits und zeigt auf das richtige Ziel.${NC}"
    fi
else
    # Wenn der Symlink nicht existiert, erstelle ihn
    echo -e "${GREY}Symlink $SYSLINK_PATH existiert nicht. Erstellen...${NC}"
    sudo ln -s "$DEVOPS_CLI_FILE" "$SYSLINK_PATH"
fi
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

# Speichern der Konfiguration
cat <<- EOL > "$CONFIG_FILE"
# system_name: Der Name des Systems oder Servers, der für die Konfiguration verwendet wird.
# Wenn der Benutzer keinen Namen eingibt, wird ein Standardname generiert.
system_name: "$SYSTEM_NAME"

# ssh_port: Der SSH-Port, über den die Verbindung zum Server hergestellt wird.
# Standardmäßig wird Port 282 verwendet, falls der Benutzer keinen Port angibt.
ssh_port: "$SSH_PORT"

# log_level: Das gewünschte Log-Level für die Protokollierung der Anwendung.
# Mögliche Optionen sind "debug", "info", "warn" und "error".
# Wenn der Benutzer keinen Wert angibt, wird "info" verwendet.
log_level: "$LOG_LEVEL"

# opt: Das Datenverzeichnis, in dem Anwendungsdaten gespeichert werden.
# Dieses Verzeichnis basiert standardmäßig auf dem system_name (z.B. /opt/$SYSTEM_NAME/data),
# falls der Benutzer kein anderes Verzeichnis angibt.
opt_data_dir: "$OPT_DATA_DIR"

# use_defaults: Eine Flag-Variable, die angibt, ob das Skript im "Default-Modus" ausgeführt wird.
# Wenn use_defaults auf "true" gesetzt ist, werden keine Eingabeaufforderungen an den Benutzer gestellt.
# Stattdessen werden automatisch die Standardwerte verwendet.
use_defaults: "$USE_DEFAULTS"

# TOOLS: Diese Variable enthält die Liste der Tools, die installiert werden sollen.
# Der Benutzer kann die Tools manuell eingeben (z.B. docker ansible terraform) oder, 
# falls keine Eingabe erfolgt, wird der Standardwert verwendet, der alle Tools umfasst.
# Wenn die Option USE_DEFAULTS=true gesetzt ist, werden automatisch alle Standardtools
# ausgewählt, ohne eine Benutzereingabe zu erfordern.
tools: "$TOOLS"

# SSH_KEY_FUNCTION_ENABLED: Diese Variable gibt an, ob die SSH-Key-Funktion aktiviert ist.
# Sie wird auf "false" gesetzt, wenn kein SSH-Key angegeben wird oder die Funktion
# standardmäßig deaktiviert ist. Wenn ein gültiger SSH-Schlüssel eingegeben wird,
# wird sie auf "true" gesetzt und die SSH-Key-Funktion wird aktiviert.
ssh_key_function_enabled: "$SSH_KEY_FUNCTION_ENABLED"

# SSH_KEY_PUBLIC: Diese Variable enthält den öffentlichen SSH-Schlüssel (Public Key),
# den der Benutzer eingegeben hat. Wenn kein Schlüssel eingegeben wird, bleibt diese
# Variable leer (""). Wenn ein gültiger SSH-Schlüssel eingegeben wird, wird dieser hier gespeichert.
ssh_key_public: "$SSH_KEY_PUBLIC"

# tools_dir: Speichert den Pfad zu dem Verzeichnis, in dem verschiedene Tools (z.B. Ansible, Docker, Terraform)
# abgelegt sind. Dies ist der Ort, an dem alle Tool-spezifischen Dateien oder Konfigurationen gespeichert werden.
tools_dir: "$TOOLS_DIR"

# scripts_dir: Speichert den Pfad zu dem Verzeichnis, in dem allgemeine Skripte abgelegt sind.
# Hier befinden sich Automatisierungsskripte oder Hilfsskripte, die für verschiedene Aufgaben oder Prozesse genutzt werden.
scripts_dir: "$SCRIPTS_DIR"

# pipelines_dir: Speichert den Pfad zu dem Verzeichnis, in dem Pipeline-Konfigurationsdateien (z.B. CI/CD-Pipelines) gespeichert sind.
# Dieses Verzeichnis enthält die Dateien für Jenkins, GitLab CI oder andere CI/CD-Tools, die in Automatisierungsprozesse integriert sind.
pipelines_dir: "$PIPELINES_DIR"

# Diese Variable wird verwendet, um den aktuellen Benutzer im System zu identifizieren.
# Der Wert von $USERNAME wird zur Laufzeit aus der Umgebung übernommen, sodass keine manuelle Eingabe erforderlich ist.
username: "$USERNAME"

# Der Pfad zur Logdatei, in die alle Protokollmeldungen geschrieben werden, wird durch die Umgebungsvariable $LOG_FILE bestimmt.
# Der Pfad kann z.B. auf "/var/log/myapp.log" oder einen anderen gewünschten Ort gesetzt werden.
log_file: "$LOG_FILE"

# Der Pfad zum System-Symlink, der auf eine bestimmte Datei oder ein Verzeichnis verweist, wird durch die Umgebungsvariable festgelegt.
# Der Wert kann z.B. auf "/usr/local/bin/myapp" gesetzt sein, um auf eine ausführbare Datei zu verweisen.
systemlink_path: "$SYSLINK_PATH"

vault_file: "$VAULT_FILE"

vault_secret: "$VAULT_SECRET"

vault_content: "$VAULT_CONTENT"

vault_mail: "$VAULT_MAIL"

clone_dir: "$CLONE_DIR"

branch: "$BRANCH"

# AAT (Ansible Automation Tools) Integration
aat_enabled: "$AAT_ENABLED"
aat_repo_url: "$AAT_REPO_URL"
aat_dir: "$AAT_DIR"

# TID (Terraform Infrastructure Deployment) Integration
tid_enabled: "$TID_ENABLED"
tid_repo_url: "$TID_REPO_URL"
tid_dir: "$TID_DIR"

EOL
echo -e "${GREY}Configuration saved in $CONFIG_FILE.${NC}"
}

installAvailableTools() {
# Überprüfen, ob install_tools.sh existiert und ausführen
if [ -f "$CLONE_DIR/environments/install_tools.sh" ]; then
    echo -e "${GREY}Switching to $CLONE_DIR/environments/install_tools.sh${NC}"
    bash "$CLONE_DIR/environments/install_tools.sh" "$TOOLS_DIR" "$TOOLS"
    
    # Weiter im Skript, nachdem install_tools.sh ausgeführt wurde
    echo -e "${GREY}Returned from install_tools.sh, continuing...${NC}"
else
    echo -e "${RED}Error: $CLONE_DIR/environments/install_tools.sh not found!${NC}"
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
echo -e "${GREY}tools_dir: ${YELLOW}\"$TOOLS_DIR\"${NC}"
echo -e "${GREY}scripts_dir: ${YELLOW}\"$SCRIPTS_DIR\"${NC}"
echo -e "${GREY}pipelines_dir: ${YELLOW}\"$PIPELINES_DIR\"${NC}\n"

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
    local spinstr='|/-\'
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
