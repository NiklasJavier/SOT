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
    
    commands=(
        'setup:Server-Konfiguration mit Ansible ausführen'
        'vault:Vault interaktiv bearbeiten (view/edit/rekey)'
        'runner:Ansible/Terraform Playbooks ausführen'
        'update:SOT auf die neueste Version aktualisieren'
        'delete:SOT-Installation entfernen'
        'validate:Integration-Status prüfen'
        'help:Hilfe anzeigen'
        'version:Version anzeigen'
    )
    
    integrations=(
        'aat:Ansible Automation Tools'
        'tid:Terraform Infrastructure Deployment'
    )
    
    vault_actions=(
        'view:Vault-Inhalt anzeigen (read-only)'
        'edit:Vault interaktiv bearbeiten'
        'rekey:Vault-Passwort ändern'
    )
    
    runner_targets=(
        'aat:AAT Playbook ausführen'
        'ansible:Ansible Playbook ausführen'
        'tid:TID Modul ausführen'
        'terraform:Terraform Modul ausführen'
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
                aat|tid)
                    _alternative \
                        'actions:Aktion:((sync\:"Repository synchronisieren" help\:"Hilfe anzeigen"))'
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
                aat|tid)
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
            esac
            ;;
        args)
            case $words[2] in
                runner)
                    _alternative \
                        'options:Option:((--tags\:"Nur bestimmte Tags" --skip-tags\:"Tags überspringen" --check\:"Dry-run" --verbose\:"Mehr Ausgabe"))'
                    ;;
            esac
            ;;
    esac
}

_sot "$@"
