#!/usr/bin/env bash
# SOT Setup Library: Setup Tasks
# Individual setup tasks that can be run independently
#
# Usage: source "$SETUP_LIB_DIR/tasks.sh"

# Prevent multiple sourcing
[[ -n "${_SOT_SETUP_TASKS_LOADED:-}" ]] && return 0
_SOT_SETUP_TASKS_LOADED=1

# Check if settings directory already exists
# Returns: 0 if doesn't exist, exits if exists
task_check_settings_dir() {
    if [[ -d "$SETTINGS_DIR" ]]; then
        err "Settings directory exists: ${YELLOW}$SETTINGS_DIR${NC}"
        err "Please use ${YELLOW}'SOT debug update'${RED} to apply the latest changes or ${YELLOW}'SOT debug delete'${RED} to remove the current setup."
        exit 1
    else
        info "Settings directory does not exist: ${YELLOW}$SETTINGS_DIR${NC}"
    fi
}

# Display startup banner and configuration overview
task_show_overview() {
    echo -e "${PINK}    ____            ____            "
    echo -e "${PINK}   / __ \\___ _   __/ __ \\____  _____"
    echo -e "${PINK}  / / / / _ \\ | / / / / / __ \\/ ___/"
    echo -e "${PINK} / /_/ /  __/ |/ / /_/ / /_/ (__  ) "
    echo -e "${PINK}/_____/\\___/|___/\\____/ .___/____/  "
    echo -e "${PINK}                     /_/            "
    echo -e "${PINK}                                    "
    
    echo -e "${GREY}Branch: ${YELLOW}$BRANCH ${NC}"
    echo -e "${GREY}Full HostSetup: ${YELLOW}${FULL:-false} ${NC}"
    echo -e "${GREY}Verwendete Tools: ${YELLOW}$TOOLS ${NC}"
    echo -e "${GREY}Port: ${YELLOW}$SSH_PORT ${NC}"
    echo -e "${GREY}Benutzername: ${YELLOW}$USERNAME ${NC}"
    echo -e "${GREY}Systemname: ${YELLOW}$SYSTEM_NAME ${NC}"
    echo -e "${GREY}SSH Key aktiviert: ${YELLOW}${SSH_KEY_FUNCTION_ENABLED:-false} ${NC}"
    echo -e "${GREY}SSH Key Public: ${YELLOW}${SSH_KEY_PUBLIC:-} ${NC}"
    echo -e "${GREY}Branch-Verzeichnis: ${YELLOW}$BRANCH_DIR ${NC}"
    echo -e "${GREY}Einstellungsverzeichnis: ${YELLOW}$SETTINGS_DIR ${NC}"
    echo -e "${GREY}Konfigurationsdatei: ${YELLOW}$CONFIG_FILE ${NC}"
    echo -e "${GREY}Skriptverzeichnis: ${YELLOW}$SCRIPTS_DIR ${NC}"
    echo -e "${GREY}Pipeline-Verzeichnis: ${YELLOW}$PIPELINES_DIR ${NC}"
    echo -e "${GREY}Systemlink: ${YELLOW}$SYSTEMLINK_PATH ${NC}"
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

# Check if running as root
# Returns: 0 if root, exits otherwise
task_check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        err "Please run as root."
        exit 1
    else
        info "Running as root..."
    fi
}

# Clone or update the main repository
task_clone_repository() {
    # Ensure git is installed
    if ! command -v git &> /dev/null; then
        info "Git is not installed. Installing Git..."
        sudo apt-get update
        sudo apt-get install -y git
        
        if ! command -v git &> /dev/null; then
            err "Git installation failed. Aborting..."
            exit 1
        else
            info "Git installed successfully."
        fi
    else
        info "Git is already installed."
    fi

    # Create directory if needed
    if [[ ! -d "$CLONE_DIR" ]]; then
        info "Creating directory $CLONE_DIR..."
        sudo mkdir -p "$CLONE_DIR"
    fi

    # Clone or reset
    if [[ -d "$CLONE_DIR/.git" ]]; then
        info "Repository already exists. Resetting to latest remote state..."
        cd "$CLONE_DIR" || exit
        # Fetch und hard reset - überschreibt ALLE lokalen Änderungen
        sudo git fetch origin "$BRANCH"
        sudo git reset --hard "origin/$BRANCH"
        sudo git clean -fd
        info "Repository auf origin/$BRANCH zurückgesetzt."
    else
        info "Cloning the repository into $CLONE_DIR with branch $BRANCH..."
        if ! sudo git clone -b "$BRANCH" --single-branch "$REPO_URL" "$CLONE_DIR"; then
            err "Failed to clone the repository. Aborting..."
            exit 1
        fi
    fi
}

# Create settings and environment folders
task_create_settings_folder() {
    # Branch-specific folder
    if [[ ! -d "$BRANCH_DIR" ]]; then
        info "Creating branch-specific folder: $BRANCH_DIR..."
        mkdir -p "$BRANCH_DIR"
    else
        info "Branch-specific folder already exists: $BRANCH_DIR..."
    fi

    # Settings folder
    if [[ ! -d "$SETTINGS_DIR" ]]; then
        info "Creating .settings folder in $BRANCH_DIR..."
        mkdir -p "$SETTINGS_DIR"
    else
        info ".settings folder already exists in $BRANCH_DIR..."
    fi

    # Overrides directory
    if [[ ! -d "$OVERRIDES_DIR" ]]; then
        info "Creating overrides directory at $OVERRIDES_DIR..."
        mkdir -p "$OVERRIDES_DIR"
    fi

    # Create config file
    touch -f "$SETTINGS_DIR/config.yaml"
}

# Edit CLI wrapper file to include config path and SOT_ROOT
task_edit_cli_wrapper() {
    # SOT_ROOT einfügen (ersetzt Placeholder)
    local sot_root_line="SOT_ROOT=\"$SOT_ROOT\""
    sed -i "s|# __SOT_ROOT_PLACEHOLDER__|$sot_root_line|g" "$CLI_WRAPPER_FILE"
    info "SOT_ROOT wurde in $CLI_WRAPPER_FILE gesetzt: $SOT_ROOT"
    
    # Config-Pfad einfügen (nach dem SOT_ROOT Kommentar)
    local cli_config_line="CONFIG_FILE=\"$CONFIG_FILE\""
    # Füge nach der SOT_ROOT Zeile ein
    sed -i "/^SOT_ROOT=/a $cli_config_line" "$CLI_WRAPPER_FILE"
    info "CONFIG_FILE wurde in $CLI_WRAPPER_FILE gesetzt."
}

# Create symlinks for CLI access
task_create_cli_symlink() {
    _ensure_symlink() {
        local link_path="$1"
        local target="$2"

        if [[ -L "$link_path" ]]; then
            if [[ "$(readlink "$link_path")" != "$target" ]]; then
                info "Symlink $link_path existiert und zeigt auf einen anderen Pfad. Aktualisierung..."
                sudo ln -sf "$target" "$link_path"
            else
                info "Symlink $link_path existiert bereits und zeigt auf das richtige Ziel."
            fi
        else
            info "Symlink $link_path existiert nicht. Erstellen..."
            sudo ln -sf "$target" "$link_path"
        fi
    }

    # CLI Symlink (SOT/sot command)
    _ensure_symlink "$SYSTEMLINK_PATH" "$SOT_ROOT/bin/sot"

    # Create lowercase variant if different
    local lowercase_link_dir
    local lowercase_link_path
    lowercase_link_dir="$(dirname "$SYSTEMLINK_PATH")"
    lowercase_link_path="${lowercase_link_dir}/$(basename "$SYSTEMLINK_PATH" | tr '[:upper:]' '[:lower:]')"

    if [[ "$lowercase_link_path" != "$SYSTEMLINK_PATH" ]]; then
        _ensure_symlink "$lowercase_link_path" "$SOT_ROOT/bin/sot"
    fi

    # Symlinks für bin/ und lib/ unter /usr/local
    _ensure_symlink "/usr/local/lib/sot" "$SOT_ROOT/lib"
    _ensure_symlink "/usr/local/bin/sot-bin" "$SOT_ROOT/bin"
}

# Make all scripts executable
task_make_scripts_executable() {
    info "Making all scripts in $CLONE_DIR executable..."
    sudo find "$CLONE_DIR" -type f -name "*.sh" -exec chmod +x {} \;
    info "Setup completed! Repository cloned to $CLONE_DIR and scripts are now executable."
}

# Sync all enabled extensions (AAT, TID, etc.)
# This is a generic task that handles ALL extensions based on config
task_sync_extensions() {
    # Load extensions manager if not already loaded
    local ext_manager="$SOT_ROOT/lib/extensions/manager.sh"
    if [[ -f "$ext_manager" ]]; then
        # shellcheck source=../../extensions/manager.sh
        source "$ext_manager"
    else
        warn "Extensions-Manager nicht gefunden. Überspringe Extension-Sync."
        return 0
    fi
    
    # Sync all enabled extensions
    extension_sync_all
}

# Install available tools
task_install_tools() {
    local install_script=""

    if [[ -f "$CLONE_DIR/setup/install_tools.sh" ]]; then
        install_script="$CLONE_DIR/setup/install_tools.sh"
    elif [[ -f "$SCRIPT_DIR/install_tools.sh" ]]; then
        install_script="$SCRIPT_DIR/install_tools.sh"
    fi

    if [[ -n "$install_script" ]]; then
        info "Switching to $install_script"
        bash "$install_script" "$MODULES_DIR" "$TOOLS"
        info "Returned from install_tools.sh, continuing..."
    else
        err "install_tools.sh not found under $CLONE_DIR/setup or $SCRIPT_DIR."
        exit 1
    fi
}

# Show final overview after setup
task_show_final_overview() {
    info "The initialization of the repo was successful."
    info "The following parameters have been set, but can still be adjusted under ${YELLOW}$CONFIG_FILE${GREY}."
    echo -e "${GREY}Nutze Standardwerte: ${YELLOW}\"$USE_DEFAULTS\" ${GREY}tools: ${YELLOW}\"$TOOLS\"${NC}\n"

    echo -e "${GREY}# system_name: System-/Servername (Standard: generiert) + username: Aktueller Benutzer${NC}"
    echo -e "${GREY}system_name: ${YELLOW}\"$SYSTEM_NAME\" ${GREY}username: ${YELLOW}\"$USERNAME\"${NC}\n"

    echo -e "${GREY}# ssh_port: SSH-Port (Standard: 282).${NC}"
    echo -e "${GREY}ssh_port: ${YELLOW}\"$SSH_PORT\"${NC}\n"

    echo -e "${GREY}# ssh_key_function_enabled: SSH-Key-Funktion aktiv (true/false).${NC}"
    echo -e "${GREY}ssh_key_function_enabled: ${YELLOW}\"${SSH_KEY_FUNCTION_ENABLED:-false}\"${NC}"
    echo -e "${GREY}ssh_key_public: ${YELLOW}\"${SSH_KEY_PUBLIC:-}\"${NC}\n"

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

    echo -e "${GREEN}*** Extensions (AAT, TID) installieren ***${NC}"
    echo -e "${GREY}>>> Verwende '${YELLOW}sot ex list${GREY}' um verfügbare Extensions anzuzeigen${NC}"
    echo -e "${GREY}>>> Verwende '${YELLOW}sot ex install aat${GREY}' oder '${YELLOW}sot ex install tid${GREY}' zum Installieren${NC}\n"

    echo -e "${GREY}*** Playbooks can be started via commands ***${NC}"
    echo -e "${GREY}>>> To do this, use '${RED}SOT${GREY}' to see a list of all possible actions.${NC}\n"
}
