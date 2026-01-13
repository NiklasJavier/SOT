#compdef SOT sot
# =============================================================================
# SOT Zsh Completion
# =============================================================================
# Installation:
#   cp sot-completion.zsh ~/.zsh/completions/_sot
#   oder zu fpath hinzufügen
# =============================================================================

_sot() {
    local -a commands
    local -a integrations
    local -a vault_actions
    local -a runner_targets
    local -a integrations_cmds
    
    # Dynamische Integrationen aus Config laden
    local config_file="${SOT_CONFIG_FILE:-/etc/DevOpsToolkit/services/default_config.yml}"
    local -a dynamic_integrations
    if [[ -f "$config_file" ]]; then
        dynamic_integrations=(${(f)"$(grep -oE '^[a-z]+_enabled:' "$config_file" 2>/dev/null | \
            sed 's/_enabled://' | \
            grep -vE '^(runner|vault|ansible|ssh)$')"})
    fi
    # Fallback auf bekannte Integrationen
    [[ ${#dynamic_integrations[@]} -eq 0 ]] && dynamic_integrations=(aat tid)
    
    commands=(
        'setup:Server-Konfiguration mit Ansible ausführen'
        'vault:Vault interaktiv bearbeiten (view/edit/rekey)'
        'runner:Ansible/Terraform Playbooks ausführen'
        'update:SOT auf die neueste Version aktualisieren'
        'delete:SOT-Installation entfernen'
        'validate:Alle Integrationen validieren'
        'integrations:Integrationen verwalten'
        'help:Hilfe anzeigen'
        'version:Version anzeigen'
    )
    
    # Dynamische Integrationen als Completion-Array
    integrations=()
    for int in "${dynamic_integrations[@]}"; do
        integrations+=("${int}:${int:u} Integration")
    done
    
    vault_actions=(
        'view:Vault-Inhalt anzeigen (read-only)'
        'edit:Vault interaktiv bearbeiten'
        'rekey:Vault-Passwort ändern'
    )
    
    runner_targets=()
    for int in "${dynamic_integrations[@]}"; do
        runner_targets+=("${int}:${int:u} ausführen")
    done
    runner_targets+=(
        'ansible:Lokales Ansible Playbook ausführen'
        'terraform:Terraform Modul ausführen'
    )
    
    integrations_cmds=(
        'list:Alle Integrationen anzeigen'
        'validate:Alle Integrationen validieren'
        'add:Neue Integration hinzufügen'
        'help:Hilfe anzeigen'
    )
    
    _arguments -C \
        '1: :->command' \
        '2: :->subcommand' \
        '3: :->option' \
        '*: :->args'
    
    case $state in
        command)
            _describe 'SOT Befehl' commands
            _describe 'Integration' integrations
            _alternative \
                'options:Option:((--help\:"Hilfe anzeigen" --version\:"Version anzeigen" --interactive\:"Interaktives Menü" --completion\:"Shell-Completion generieren"))'
            ;;
        subcommand)
            case $words[2] in
                aat|tid|${(~j:|:)dynamic_integrations})
                    _alternative \
                        'actions:Aktion:((sync\:"Repository synchronisieren" validate\:"Integration validieren" help\:"Hilfe anzeigen"))'
                    ;;
                vault)
                    _describe 'Vault-Aktion' vault_actions
                    ;;
                runner)
                    _describe 'Runner-Ziel' runner_targets
                    ;;
                setup)
                    _alternative \
                        'options:Option:((--check\:"Dry-run ohne Änderungen" --tags\:"Nur bestimmte Tags ausführen" --help\:"Hilfe anzeigen"))'
                    ;;
                integrations)
                    _describe 'Integrations-Befehl' integrations_cmds
                    ;;
                help)
                    _describe 'Befehl' commands
                    _describe 'Integration' integrations
                    ;;
                --completion)
                    _alternative \
                        'shells:Shell:((bash\:"Bash Completion" zsh\:"Zsh Completion"))'
                    ;;
            esac
            ;;
        option)
            case $words[2] in
                aat|tid|${(~j:|:)dynamic_integrations})
                    if [[ $words[3] == "sync" ]]; then
                        _alternative \
                            'options:Option:((--branch\:"Branch zum Synchronisieren" --help\:"Hilfe anzeigen"))'
                    fi
                    ;;
                runner)
                    _files -g "*.yml"
                    ;;
                setup)
                    if [[ $words[3] == "--tags" ]]; then
                        _values 'Tags' ssh firewall docker users packages security monitoring
                    fi
                    ;;
                integrations)
                    if [[ $words[3] == "add" ]]; then
                        _alternative \
                            'types:Typ:((ansible\:"Ansible Integration" terraform\:"Terraform Integration" custom\:"Custom Runner" script\:"Shell Script"))'
                    fi
                    ;;
            esac
            ;;
        args)
            ;;
    esac
}

_sot "$@"
