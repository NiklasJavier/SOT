#!/usr/bin/env bash
# =============================================================================
# SOT Bash Completion
# =============================================================================
# Installation:
#   source /path/to/sot-completion.bash
#   oder
#   cp sot-completion.bash /etc/bash_completion.d/sot
# =============================================================================

_sot_completions() {
    local cur prev words cword
    _init_completion -n : || return

    # Basis-Befehle
    local commands="setup vault runner update delete validate help version"
    local integrations="aat tid"
    local maintenance_cmds="update delete"
    local sync_cmds="sync"
    
    case $cword in
        1)
            # Erste Ebene: Hauptbefehle + Integrationen
            COMPREPLY=($(compgen -W "$commands $integrations --help --version --interactive --completion" -- "$cur"))
            ;;
        2)
            case "${words[1]}" in
                help)
                    # Hilfe für alle Befehle
                    COMPREPLY=($(compgen -W "$commands $integrations" -- "$cur"))
                    ;;
                aat|tid)
                    # Integration-Unterbefehle
                    COMPREPLY=($(compgen -W "sync help" -- "$cur"))
                    ;;
                runner)
                    # Runner-Unterbefehle
                    COMPREPLY=($(compgen -W "aat ansible tid terraform" -- "$cur"))
                    ;;
                vault)
                    # Vault-Aktionen
                    COMPREPLY=($(compgen -W "view edit rekey" -- "$cur"))
                    ;;
                setup)
                    # Setup-Optionen
                    COMPREPLY=($(compgen -W "--check --tags --help" -- "$cur"))
                    ;;
                --completion)
                    COMPREPLY=($(compgen -W "bash zsh" -- "$cur"))
                    ;;
            esac
            ;;
        3)
            case "${words[1]}" in
                aat|tid)
                    if [[ "${words[2]}" == "sync" ]]; then
                        COMPREPLY=($(compgen -W "--branch --help" -- "$cur"))
                    fi
                    ;;
                runner)
                    # Playbook-Vorschläge (könnte erweitert werden)
                    COMPREPLY=($(compgen -W "site.yml main.yml setup.yml --help" -- "$cur"))
                    ;;
                setup)
                    if [[ "${words[2]}" == "--tags" ]]; then
                        COMPREPLY=($(compgen -W "ssh firewall docker users packages security" -- "$cur"))
                    fi
                    ;;
            esac
            ;;
    esac

    return 0
}

# Completion aktivieren
complete -F _sot_completions SOT
complete -F _sot_completions sot
