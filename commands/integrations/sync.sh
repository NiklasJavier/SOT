#!/usr/bin/env bash
# =============================================================================
# @cmd: integrations sync
# @category: sync
# @description: Generischer Sync für alle Integrationen
# @usage: SOT <integration> sync [--branch <branch>]
# @example: SOT aat sync --branch develop
# =============================================================================
## Generisches Sync-Skript für das Integrations-Framework.
## Wird automatisch für alle konfigurierten Integrationen verwendet.
## Unterstützt Branch-Override via --branch Parameter.
# =============================================================================

set -euo pipefail

# Load shared library
SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../../lib/init.sh
source "$SCRIPT_ROOT/lib/init.sh"

# =============================================================================
# Parameter parsen
# =============================================================================
INTEGRATION_NAME="${SOT_INTEGRATION_NAME:-}"
BRANCH_OVERRIDE=""

# Argumente verarbeiten
while [[ $# -gt 0 ]]; do
    case "$1" in
        --branch|-b)
            shift
            if [[ $# -eq 0 ]]; then
                err "--branch benötigt einen Wert."
                exit 1
            fi
            BRANCH_OVERRIDE="$1"
            ;;
        --integration|-i)
            shift
            if [[ $# -eq 0 ]]; then
                err "--integration benötigt einen Wert."
                exit 1
            fi
            INTEGRATION_NAME="$1"
            ;;
        --help|-h)
            echo "Usage: SOT <integration> sync [--branch <branch>]"
            echo ""
            echo "Options:"
            echo "  --branch, -b    Branch zum Synchronisieren"
            echo "  --help, -h      Diese Hilfe anzeigen"
            exit 0
            ;;
        *)
            # Ignoriere unbekannte Argumente (CLI Metadata)
            ;;
    esac
    shift || true
done

# =============================================================================
# Hauptlogik
# =============================================================================

if [[ -z "$INTEGRATION_NAME" ]]; then
    err "Keine Integration angegeben."
    err "Usage: SOT <integration> sync [--branch <branch>]"
    exit 1
fi

# Config laden falls noch nicht geschehen
if [[ -z "${INTEGRATIONS[$INTEGRATION_NAME]:-}" ]]; then
    # Versuche Integration zu finden
    discover_integrations
fi

# Sync ausführen
if integration_exists "$INTEGRATION_NAME"; then
    sync_integration "$INTEGRATION_NAME" "$BRANCH_OVERRIDE"
    exit $?
else
    err "Integration '$INTEGRATION_NAME' nicht gefunden oder deaktiviert."
    info "Verfügbare Integrationen mit 'SOT integrations list' anzeigen."
    exit 1
fi
