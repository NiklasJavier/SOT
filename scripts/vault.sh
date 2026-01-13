#!/usr/bin/env bash
#
# SOT Vault Management
# Sichere Interaktion mit dem Ansible-Vault
#
set -euo pipefail

# =============================================================================
# Bibliothek laden
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -f "$SCRIPT_ROOT/lib/init.sh" ]]; then
    source "$SCRIPT_ROOT/lib/init.sh"
else
    # Fallback-Farben wenn lib nicht verfügbar
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    PINK='\033[0;35m'
    GREY='\033[1;90m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
fi

# =============================================================================
# Konfiguration
# =============================================================================
vault_file="${4:-}"
vault_secret="${5:-}"
PASS_FILE=""

# Sichere temporäre Verzeichnisse (in Reihenfolge der Präferenz)
SECURE_TMP_DIRS=(
    "${XDG_RUNTIME_DIR:-}"
    "/dev/shm"
    "/run/user/$(id -u)"
    "${TMPDIR:-/tmp}"
)

# =============================================================================
# Sichere Funktionen
# =============================================================================

# Findet ein sicheres temporäres Verzeichnis
findSecureTmpDir() {
    for dir in "${SECURE_TMP_DIRS[@]}"; do
        if [[ -n "$dir" && -d "$dir" && -w "$dir" ]]; then
            # Prüfe ob tmpfs (RAM-basiert, sicherer)
            if mount | grep -q "on $dir type tmpfs"; then
                echo "$dir"
                return 0
            fi
        fi
    done
    
    # Fallback auf /tmp mit Warnung
    echo -e "${YELLOW}⚠️  Warnung: Kein RAM-basiertes tmpfs gefunden, verwende /tmp${NC}" >&2
    echo "/tmp"
}

# Prüft ob shred verfügbar ist
hasShred() {
    command -v shred &>/dev/null
}

# Sichere Löschung einer Datei
secureDelete() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    
    if hasShred; then
        # shred überschreibt Datei mehrfach vor dem Löschen
        shred -u -z -n 3 "$file" 2>/dev/null || rm -f "$file"
    else
        # Fallback: Überschreiben mit Nullen, dann löschen
        dd if=/dev/zero of="$file" bs=1k count=1 2>/dev/null || true
        sync
        rm -f "$file"
    fi
}

# Cleanup-Handler für alle Exit-Szenarien
cleanup() {
    local exit_code=$?
    
    if [[ -n "${PASS_FILE:-}" && -f "$PASS_FILE" ]]; then
        secureDelete "$PASS_FILE"
        echo -e "${GREY}Temporäre Zugriffsdatei sicher gelöscht.${NC}"
    fi
    
    exit $exit_code
}

# Registriere Cleanup für alle Exit-Szenarien
trap cleanup EXIT INT TERM HUP

# =============================================================================
# Vault-Funktionen
# =============================================================================

checkIfVaultExists() {
    if [[ -z "$vault_file" ]]; then
        echo -e "${RED}Fehler: Vault-Datei nicht angegeben.${NC}"
        exit 1
    fi
    
    if [[ ! -f "$vault_file" ]]; then
        echo -e "${RED}Die Vault-Datei ${YELLOW}$vault_file ${RED}existiert nicht.${NC}"
        exit 1
    fi
    
    echo -e "${GREY}Die Vault-Datei ${YELLOW}$vault_file ${GREY}existiert.${NC}"
}

createTemporaryAccessFile() {
    if [[ -z "$vault_secret" ]]; then
        echo -e "${RED}Fehler: Vault-Secret nicht angegeben.${NC}"
        exit 1
    fi
    
    # Finde sicheres Verzeichnis
    local secure_dir
    secure_dir=$(findSecureTmpDir)
    
    # Erstelle temporäre Datei mit restriktiven Rechten
    PASS_FILE=$(mktemp "${secure_dir}/vault_XXXXXX")
    
    # Setze Berechtigungen BEVOR Inhalt geschrieben wird
    chmod 600 "$PASS_FILE"
    
    # Schreibe Secret ohne Newline (printf statt echo)
    printf '%s' "$vault_secret" > "$PASS_FILE"
    
    echo -e "${GREY}Temporäre Zugriffsdatei erstellt: ${YELLOW}$PASS_FILE${NC}"
    echo -e "${GREY}(Wird automatisch sicher gelöscht)${NC}"
}

openVault() {
    if ansible-vault edit --vault-password-file="$PASS_FILE" "$vault_file"; then
        echo -e "${GREY}Die Vault-Datei ${YELLOW}$vault_file ${GREY}wurde erfolgreich geöffnet.${NC}"
    else
        echo -e "${RED}Die Vault-Datei ${YELLOW}$vault_file ${RED}konnte nicht geöffnet werden.${NC}"
        return 1
    fi
}

deleteTemporaryAccessFile() {
    if [[ -n "$PASS_FILE" && -f "$PASS_FILE" ]]; then
        secureDelete "$PASS_FILE"
        
        if [[ ! -f "$PASS_FILE" ]]; then
            echo -e "${GREY}Die temporäre Zugriffsdatei wurde sicher gelöscht.${NC}"
        else
            echo -e "${RED}Die temporäre Zugriffsdatei ${YELLOW}$PASS_FILE ${RED}konnte nicht gelöscht werden.${NC}"
            exit 1
        fi
    fi
    
    # Verhindere doppeltes Löschen im Cleanup
    PASS_FILE=""
}

# =============================================================================
# Hauptprogramm
# =============================================================================

methods=(
    checkIfVaultExists
    createTemporaryAccessFile
    openVault
    deleteTemporaryAccessFile
)

for method in "${methods[@]}"; do
    echo -e "\n${GREY}======= ${GREEN}Running: ${PINK}[$method] ${GREY}=======${NC}"
    $method
done
