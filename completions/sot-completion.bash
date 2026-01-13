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
    local commands="setup vault runner update delete validate integrations help version"
    
    # Dynamische Integrationen aus Config laden (falls verfügbar)
    local integrations=""
    local config_file="${SOT_CONFIG_FILE:-/etc/DevOpsToolkit/config/default_config.yml}"
    if [[ -f "$config_file" ]]; then
        integrations=$(grep -oE '^[a-z]+_enabled:' "$config_file" 2>/dev/null | \
            sed 's/_enabled://' | \
            grep -vE '^(runner|vault|ansible|ssh)$' | \
            tr '\n' ' ')
    fi
    # Fallback auf bekannte Integrationen
    [[ -z "$integrations" ]] && integrations="aat tid"
    
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
                integrations)
                    # Integrations-Unterbefehle
                    COMPREPLY=($(compgen -W "list validate add help" -- "$cur"))
                    ;;
                runner)
                    # Runner-Unterbefehle (dynamische Integrationen)
                    COMPREPLY=($(compgen -W "$integrations" -- "$cur"))
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
                *)
                    # Dynamische Integration erkannt?
                    if [[ " $integrations " =~ " ${words[1]} " ]]; then
                        COMPREPLY=($(compgen -W "sync validate help" -- "$cur"))
                    fi
                    ;;
            esac
            ;;
        3)
            case "${words[1]}" in
                runner)
                    # Playbook-Vorschläge
                    COMPREPLY=($(compgen -W "site.yml main.yml setup.yml --help" -- "$cur"))
                    ;;
                setup)
                    if [[ "${words[2]}" == "--tags" ]]; then
                        COMPREPLY=($(compgen -W "ssh firewall docker users packages security" -- "$cur"))
                    fi
                    ;;
                integrations)
                    if [[ "${words[2]}" == "add" ]]; then
                        COMPREPLY=($(compgen -W "ansible terraform custom script" -- "$cur"))
                    fi
                    ;;
                *)
                    # Dynamische Integration mit sync
                    if [[ " $integrations " =~ " ${words[1]} " && "${words[2]}" == "sync" ]]; then
                        COMPREPLY=($(compgen -W "--branch --help" -- "$cur"))
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
