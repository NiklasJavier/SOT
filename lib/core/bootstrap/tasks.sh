#!/usr/bin/env bash
# SOT Bootstrap Library: Bootstrap Tasks
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
        err "Settings-Verzeichnis existiert bereits: $(highlight "$SETTINGS_DIR")"
        err "Nutze $(highlight "sot debug update") zum Aktualisieren oder $(highlight "sot debug delete") zum Entfernen"
        exit 1
    else
        info "Settings-Verzeichnis existiert nicht: $(highlight "$SETTINGS_DIR")"
    fi
}

# Display startup banner and configuration overview
task_show_overview() {
    # Only show in debug mode, otherwise skip
    if [[ "${DEBUG_MODE:-false}" != "true" ]]; then
        return 0
    fi
    
    echo ""
    echo -e "${MAGENTA}    ____            ____            "
    echo -e "${MAGENTA}   / __ \\___ _   __/ __ \\____  _____"
    echo -e "${MAGENTA}  / / / / _ \\ | / / / / / __ \\/ ___/"
    echo -e "${MAGENTA} / /_/ /  __/ |/ / /_/ / /_/ (__  ) "
    echo -e "${MAGENTA}/_____/\\___/|___/\\____/ .___/____/  "
    echo -e "${MAGENTA}                     /_/            ${NC}"
    echo ""
    
    label "Konfigurationsübersicht"
    echo ""
    echo "  Branch:                   $(highlight "$BRANCH")"
    echo "  Full HostSetup:           $(highlight "${FULL:-false}")"
    echo "  Tools:                    $(highlight "$TOOLS")"
    echo "  SSH Port:                 $(highlight "$SSH_PORT")"
    echo "  Benutzername:             $(highlight "$USERNAME")"
    echo "  Systemname:               $(highlight "$SYSTEM_NAME")"
    echo "  SSH Key aktiviert:        $(highlight "${SSH_KEY_FUNCTION_ENABLED:-false}")"
    echo "  Branch-Verzeichnis:       $(highlight "$BRANCH_DIR")"
    echo "  Einstellungsverzeichnis:  $(highlight "$SETTINGS_DIR")"
    echo "  Konfigurationsdatei:      $(highlight "$CONFIG_FILE")"
    echo "  AAT Enabled:              $(highlight "$AAT_ENABLED")"
    echo "  TID Enabled:              $(highlight "$TID_ENABLED")"
    echo "  Runner Enabled:           $(highlight "$RUNNER_ENABLED")"
    echo ""
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
        info "Git wird installiert..."
        sudo apt-get update
        sudo apt-get install -y git
        
        if ! command -v git &> /dev/null; then
            err "Git-Installation fehlgeschlagen"
            exit 1
        else
            success "Git erfolgreich installiert"
        fi
    else
        info "Git ist bereits installiert"
    fi

    # Create directory if needed
    if [[ ! -d "$CLONE_DIR" ]]; then
        info "Erstelle Verzeichnis $(highlight "$CLONE_DIR")"
        sudo mkdir -p "$CLONE_DIR"
    fi

    # Clone or reset
    if [[ -d "$CLONE_DIR/.git" ]]; then
        info "Repository existiert bereits - setze auf neuesten Stand zurück"
        cd "$CLONE_DIR" || exit
        # Fetch und hard reset - überschreibt ALLE lokalen Änderungen
        sudo git fetch origin "$BRANCH"
        sudo git reset --hard "origin/$BRANCH"
        sudo git clean -fd
        success "Repository auf $(highlight "origin/$BRANCH") zurückgesetzt"
    else
        info "Klone Repository (Branch: $(highlight "$BRANCH"))"
        if ! sudo git clone -b "$BRANCH" --single-branch "$REPO_URL" "$CLONE_DIR"; then
            err "Repository konnte nicht geklont werden"
            exit 1
        fi
    fi
}

# Create settings and environment folders
task_create_settings_folder() {
    # Branch-specific folder
    if [[ ! -d "$BRANCH_DIR" ]]; then
        info "Erstelle Branch-Verzeichnis: $(highlight "$BRANCH_DIR")"
        mkdir -p "$BRANCH_DIR"
    else
        info "Branch-Verzeichnis existiert bereits"
    fi

    # Settings folder
    if [[ ! -d "$SETTINGS_DIR" ]]; then
        info "Erstelle .settings Verzeichnis"
        mkdir -p "$SETTINGS_DIR"
    else
        info ".settings Verzeichnis existiert bereits"
    fi

    # Overrides directory
    if [[ ! -d "$OVERRIDES_DIR" ]]; then
        info "Erstelle Overrides-Verzeichnis"
        mkdir -p "$OVERRIDES_DIR"
    fi

    # Create config file
    touch -f "$SETTINGS_DIR/config.yaml"
}

# Edit CLI file to include config path and SOT_ROOT
task_edit_cli() {
    # SOT_ROOT einfügen (ersetzt Placeholder)
    local sot_root_line="SOT_ROOT=\"$SOT_ROOT\""
    sed -i "s|# __SOT_ROOT_PLACEHOLDER__|$sot_root_line|g" "$CLI_FILE"
    info "SOT_ROOT gesetzt: $(highlight "$SOT_ROOT")"
    
    # Config-Pfad einfügen (nach dem SOT_ROOT Kommentar)
    local cli_config_line="CONFIG_FILE=\"$CONFIG_FILE\""
    # Füge nach der SOT_ROOT Zeile ein
    sed -i "/^SOT_ROOT=/a $cli_config_line" "$CLI_FILE"
    info "CONFIG_FILE gesetzt: $(highlight "$CONFIG_FILE")"
}

# Create symlinks for CLI access
task_create_cli_symlink() {
    _ensure_symlink() {
        local link_path="$1"
        local target="$2"

        if [[ -L "$link_path" ]]; then
            if [[ "$(readlink "$link_path")" != "$target" ]]; then
                info "Aktualisiere Symlink $(highlight "$link_path")"
                sudo ln -sf "$target" "$link_path"
            else
                info "Symlink existiert bereits: $(highlight "$link_path")"
            fi
        else
            info "Erstelle Symlink: $(highlight "$link_path")"
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
    info "Setze Ausführungsrechte für alle Scripts"
    sudo find "$CLONE_DIR" -type f -name "*.sh" -exec chmod +x {} \;
    success "Alle Scripts sind nun ausführbar"
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
        warn "Extensions-Manager nicht gefunden - überspringe Extension-Sync"
        return 0
    fi
    
    # Sync all enabled extensions
    extension_sync_all
}

# Install available tools
task_install_dependencies() {
    local install_script=""

    if [[ -f "$CLONE_DIR/bootstrap/dependencies.sh" ]]; then
        install_script="$CLONE_DIR/bootstrap/dependencies.sh"
    elif [[ -f "$SCRIPT_DIR/dependencies.sh" ]]; then
        install_script="$SCRIPT_DIR/dependencies.sh"
    fi

    if [[ -n "$install_script" ]]; then
        info "Switching to $install_script"
        bash "$install_script" "$MODULES_DIR" "$TOOLS"
        info "Returned from dependencies.sh, continuing..."
    else
        err "dependencies.sh not found under $CLONE_DIR/bootstrap or $SCRIPT_DIR."
        exit 1
    fi
}

# Show final overview after setup
task_show_final_overview() {
    # Only show in debug mode, otherwise show simplified message
    if [[ "${DEBUG_MODE:-false}" != "true" ]]; then
        success "Installation erfolgreich abgeschlossen"
        info "Konfiguration: $(highlight "$CONFIG_FILE")"
        echo ""
        label "Nächste Schritte:"
        echo "  • Extensions installieren: $(highlight "sot ex install aat") oder $(highlight "sot ex install tid")"
        echo "  • Verfügbare Extensions: $(highlight "sot ex list")"
        echo "  • Host-Setup ausführen: $(highlight "sot bootstrap")"
        echo ""
        return 0
    fi
    
    success "Repository-Initialisierung erfolgreich"
    info "Parameter können angepasst werden unter: $(highlight "$CONFIG_FILE")"
    echo ""
    
    label "Konfiguration"
    echo ""
    echo "  System & User:"
    echo "    system_name:              $(highlight "$SYSTEM_NAME")"
    echo "    username:                 $(highlight "$USERNAME")"
    echo ""
    echo "  SSH:"
    echo "    ssh_port:                 $(highlight "$SSH_PORT")"
    echo "    ssh_key_enabled:          $(highlight "${SSH_KEY_FUNCTION_ENABLED:-false}")"
    echo ""
    echo "  Verzeichnisse:"
    echo "    opt_data_dir:             $(highlight "$OPT_DATA_DIR")"
    echo "    modules_dir:              $(highlight "$MODULES_DIR")"
    echo "    scripts_dir:              $(highlight "$SCRIPTS_DIR")"
    echo ""
    echo "  Runner:"
    echo "    runner_enabled:           $(highlight "$RUNNER_ENABLED")"
    echo "    runner_default_mode:      $(highlight "$RUNNER_DEFAULT_MODE")"
    echo "    runner_sync_before_run:   $(highlight "$RUNNER_SYNC_BEFORE_RUN")"
    echo ""
    echo "  Logging:"
    echo "    log_file:                 $(highlight "$LOG_FILE")"
    echo "    log_level:                $(highlight "$LOG_LEVEL")"
    echo ""
    
    label "Extensions"
    echo ""
    echo "  Verfügbare Extensions: $(highlight "sot ex list")"
    echo "  AAT installieren:      $(highlight "sot ex install aat")"
    echo "  TID installieren:      $(highlight "sot ex install tid")"
    echo ""
    
    label "Playbooks starten"
    echo ""
    echo "  Alle Befehle anzeigen:  $(highlight "sot")"
    echo "  Host-Setup ausführen:   $(highlight "sot bootstrap")"
    echo ""
}
