#!/usr/bin/env bash
# =============================================================================
# SOT Doctor - System Health Check
# =============================================================================
# @cmd: doctor
# @category: system
# @description: System-Diagnose und automatische Reparatur
# @usage: SOT doctor [--fix] [--summary] [--verbose]
# @example: SOT doctor --fix
# =============================================================================
set -uo pipefail  # Kein -e, da Checks fehlschlagen dürfen

# =============================================================================
# Initialisierung
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Libraries laden
# shellcheck source=../lib/init.sh
source "$ROOT_DIR/lib/init.sh"

# =============================================================================
# Konfiguration
# =============================================================================
FIX_MODE=false
SUMMARY_MODE=false
VERBOSE_MODE=false

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0
FIXES_APPLIED=0

# Farben
readonly CHECK_OK="${GREEN:-}✓${NC:-}"
readonly CHECK_FAIL="${RED:-}✗${NC:-}"
readonly CHECK_WARN="${YELLOW:-}⚠${NC:-}"
readonly CHECK_INFO="${CYAN:-}ℹ${NC:-}"

# =============================================================================
# Argumente parsen
# =============================================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix|-f)
            FIX_MODE=true
            shift
            ;;
        --summary|-s)
            SUMMARY_MODE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: SOT doctor [--fix] [--summary] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --fix, -f      Versuche Probleme automatisch zu beheben"
            echo "  --summary, -s  Nur Zusammenfassung anzeigen"
            echo "  --verbose, -v  Ausführliche Ausgabe"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# =============================================================================
# Check-Funktionen
# =============================================================================

# Registriert ein Check-Ergebnis
check_pass() {
    local msg="$1"
    ((++CHECKS_PASSED)) || true
    [[ "$SUMMARY_MODE" != "true" ]] && printf "  %s %s\n" "$CHECK_OK" "$msg"
}

check_fail() {
    local msg="$1"
    ((++CHECKS_FAILED)) || true
    [[ "$SUMMARY_MODE" != "true" ]] && printf "  %s %s\n" "$CHECK_FAIL" "$msg"
}

check_warn() {
    local msg="$1"
    ((++CHECKS_WARNING)) || true
    [[ "$SUMMARY_MODE" != "true" ]] && printf "  %s %s\n" "$CHECK_WARN" "$msg"
}

check_info() {
    local msg="$1"
    [[ "$VERBOSE_MODE" == "true" ]] && printf "  %s %s\n" "$CHECK_INFO" "$msg"
}

fix_applied() {
    local msg="$1"
    ((++FIXES_APPLIED)) || true
    printf "  ${GREEN:-}⚡${NC:-} Fix: %s\n" "$msg"
}

section_header() {
    local title="$1"
    [[ "$SUMMARY_MODE" != "true" ]] && printf "\n${BOLD:-}%s${NC:-}\n" "$title"
}

# =============================================================================
# System-Checks
# =============================================================================

check_sot_installation() {
    section_header "📦 SOT Installation"
    
    # Prüfe ob SOT-Verzeichnis existiert
    if [[ -d "$ROOT_DIR" ]]; then
        check_pass "SOT Verzeichnis gefunden: $ROOT_DIR"
    else
        check_fail "SOT Verzeichnis nicht gefunden"
        return 1
    fi
    
    # Prüfe wichtige Dateien
    local required_files=(
        "bin/sot"
        "lib/init.sh"
        "services/default_config.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$ROOT_DIR/$file" ]]; then
            check_pass "Datei vorhanden: $file"
        else
            check_fail "Datei fehlt: $file"
            if [[ "$FIX_MODE" == "true" ]]; then
                # Versuche aus Git wiederherzustellen
                if git -C "$ROOT_DIR" checkout -- "$file" 2>/dev/null; then
                    fix_applied "Datei wiederhergestellt: $file"
                fi
            fi
        fi
    done
    
    # Prüfe Ausführungsrechte
    if [[ -x "$ROOT_DIR/bin/sot" ]]; then
        check_pass "bin/sot ist ausführbar"
    else
        check_fail "bin/sot ist nicht ausführbar"
        if [[ "$FIX_MODE" == "true" ]]; then
            chmod +x "$ROOT_DIR/bin/sot"
            fix_applied "Ausführungsrechte für bin/sot gesetzt"
        fi
    fi
}

check_dependencies() {
    section_header "🔧 Abhängigkeiten"
    
    local deps=(
        "bash:Shell"
        "git:Versionskontrolle"
        "curl:HTTP-Client"
    )
    
    local optional_deps=(
        "ansible:Ansible Automation"
        "docker:Container Runtime"
        "yamllint:YAML Linter"
        "shellcheck:Shell Linter"
    )
    
    # Pflicht-Abhängigkeiten
    for dep_info in "${deps[@]}"; do
        local dep="${dep_info%%:*}"
        local desc="${dep_info#*:}"
        
        if command -v "$dep" &>/dev/null; then
            local version
            version=$("$dep" --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "?")
            check_pass "$desc ($dep) v$version"
        else
            check_fail "$desc ($dep) nicht installiert"
        fi
    done
    
    # Optionale Abhängigkeiten
    for dep_info in "${optional_deps[@]}"; do
        local dep="${dep_info%%:*}"
        local desc="${dep_info#*:}"
        
        if command -v "$dep" &>/dev/null; then
            check_pass "$desc ($dep) verfügbar"
        else
            check_info "$desc ($dep) nicht installiert (optional)"
        fi
    done
}

check_configuration() {
    section_header "⚙️  Konfiguration"
    
    local config_file="$ROOT_DIR/services/default_config.yml"
    
    # Prüfe ob Config existiert
    if [[ -f "$config_file" ]]; then
        check_pass "Konfigurationsdatei gefunden"
    else
        check_fail "Konfigurationsdatei fehlt: $config_file"
        return 1
    fi
    
    # Prüfe YAML-Syntax
    if command -v yamllint &>/dev/null; then
        if yamllint -d "{extends: relaxed, rules: {line-length: disable}}" "$config_file" &>/dev/null; then
            check_pass "YAML-Syntax gültig"
        else
            check_fail "YAML-Syntax fehlerhaft"
        fi
    else
        # Fallback: Versuche zu parsen
        if parse_yaml_to_vars "$config_file" 2>/dev/null; then
            check_pass "Konfiguration parsebar"
        else
            check_fail "Konfiguration nicht parsebar"
        fi
    fi
    
    # Prüfe wichtige Werte
    parse_yaml_to_vars "$config_file" 2>/dev/null || true
    
    if [[ -n "${system_name:-}" ]]; then
        check_pass "system_name konfiguriert: $system_name"
    else
        check_warn "system_name nicht konfiguriert"
    fi
    
    if [[ -n "${ssh_port:-}" && "${ssh_port:-22}" =~ ^[0-9]+$ ]]; then
        check_pass "ssh_port konfiguriert: $ssh_port"
    else
        check_warn "ssh_port nicht oder fehlerhaft konfiguriert"
    fi
}

check_modules() {
    section_header "🔌 Module"
    
    local modules_dir="$ROOT_DIR/modules"
    
    if [[ ! -d "$modules_dir" ]]; then
        check_fail "Module-Verzeichnis fehlt"
        return 1
    fi
    
    local module_count=0
    local enabled_count=0
    
    for module_dir in "$modules_dir"/*/; do
        [[ ! -d "$module_dir" ]] && continue
        local module_name
        module_name=$(basename "$module_dir")
        ((++module_count)) || true
        
        # Prüfe auf module.yml
        local meta_file=""
        for candidate in "module.yml" "module.yaml" "plugin.yml" "plugin.yaml"; do
            if [[ -f "${module_dir}${candidate}" ]]; then
                meta_file="${module_dir}${candidate}"
                break
            fi
        done
        
        if [[ -n "$meta_file" ]]; then
            check_pass "Modul '$module_name' hat Metadaten"
            ((++enabled_count)) || true
        else
            check_warn "Modul '$module_name' ohne Metadaten"
        fi
        
        # Prüfe auf install.sh
        if [[ -f "${module_dir}install.sh" ]]; then
            if [[ -x "${module_dir}install.sh" ]]; then
                check_pass "Modul '$module_name' Installer ausführbar"
            else
                check_warn "Modul '$module_name' Installer nicht ausführbar"
                if [[ "$FIX_MODE" == "true" ]]; then
                    chmod +x "${module_dir}install.sh"
                    fix_applied "Ausführungsrechte für $module_name/install.sh"
                fi
            fi
        fi
    done
    
    check_info "Gefundene Module: $module_count (davon $enabled_count mit Metadaten)"
}

check_git_status() {
    section_header "📊 Git Status"
    
    if [[ ! -d "$ROOT_DIR/.git" ]]; then
        check_warn "Kein Git-Repository"
        return 0
    fi
    
    # Aktueller Branch
    local branch
    branch=$(git -C "$ROOT_DIR" branch --show-current 2>/dev/null || echo "unknown")
    check_pass "Branch: $branch"
    
    # Uncommitted changes
    local changes
    changes=$(git -C "$ROOT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$changes" -eq 0 ]]; then
        check_pass "Keine uncommitted Änderungen"
    else
        check_warn "$changes uncommitted Änderung(en)"
    fi
    
    # Remote status
    if git -C "$ROOT_DIR" remote get-url origin &>/dev/null; then
        local behind ahead
        behind=$(git -C "$ROOT_DIR" rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
        ahead=$(git -C "$ROOT_DIR" rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        
        if [[ "$behind" -gt 0 ]]; then
            check_warn "$behind Commits hinter Remote"
        elif [[ "$ahead" -gt 0 ]]; then
            check_info "$ahead Commits vor Remote"
        else
            check_pass "Synchron mit Remote"
        fi
    fi
}

check_permissions() {
    section_header "🔒 Berechtigungen"
    
    # Prüfe kritische Verzeichnisse
    local dirs_to_check=(
        "$ROOT_DIR/bin"
        "$ROOT_DIR/lib"
        "$ROOT_DIR/commands"
    )
    
    for dir in "${dirs_to_check[@]}"; do
        if [[ -d "$dir" && -r "$dir" ]]; then
            check_pass "Verzeichnis lesbar: ${dir#$ROOT_DIR/}"
        elif [[ -d "$dir" ]]; then
            check_fail "Verzeichnis nicht lesbar: ${dir#$ROOT_DIR/}"
        fi
    done
    
    # Prüfe Skript-Berechtigungen
    local script_count=0
    local not_executable=0
    
    while IFS= read -r -d '' script; do
        ((++script_count)) || true
        if [[ ! -x "$script" ]]; then
            ((++not_executable)) || true
            check_warn "Nicht ausführbar: ${script#$ROOT_DIR/}"
            if [[ "$FIX_MODE" == "true" ]]; then
                chmod +x "$script"
                fix_applied "Ausführungsrechte gesetzt: ${script#$ROOT_DIR/}"
            fi
        fi
    done < <(find "$ROOT_DIR/bin" "$ROOT_DIR/commands" -type f -name "*.sh" -print0 2>/dev/null)
    
    if [[ "$not_executable" -eq 0 ]]; then
        check_pass "Alle $script_count Skripte sind ausführbar"
    fi
}

# =============================================================================
# Zusammenfassung
# =============================================================================

show_summary() {
    local total=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNING))
    local status_color="${GREEN:-}"
    local status_text="Gesund"
    local status_emoji="✅"
    
    if [[ "$CHECKS_FAILED" -gt 0 ]]; then
        status_color="${RED:-}"
        status_text="Probleme gefunden"
        status_emoji="❌"
    elif [[ "$CHECKS_WARNING" -gt 0 ]]; then
        status_color="${YELLOW:-}"
        status_text="Warnungen vorhanden"
        status_emoji="⚠️"
    fi
    
    printf "\n"
    printf "  %s═══════════════════════════════════════════════════════════%s\n" "${BOLD:-}" "${NC:-}"
    printf "  %s SOT Health Check - Zusammenfassung%s\n" "${BOLD:-}" "${NC:-}"
    printf "  %s═══════════════════════════════════════════════════════════%s\n" "${BOLD:-}" "${NC:-}"
    printf "\n"
    printf "  Status: %s%s %s%s\n" "$status_color" "$status_emoji" "$status_text" "${NC:-}"
    printf "\n"
    printf "  ${GREEN:-}✓${NC:-} Bestanden:  %d\n" "$CHECKS_PASSED"
    printf "  ${YELLOW:-}⚠${NC:-} Warnungen:  %d\n" "$CHECKS_WARNING"
    printf "  ${RED:-}✗${NC:-} Fehler:     %d\n" "$CHECKS_FAILED"
    
    if [[ "$FIXES_APPLIED" -gt 0 ]]; then
        printf "\n"
        printf "  ${GREEN:-}⚡${NC:-} Fixes angewendet: %d\n" "$FIXES_APPLIED"
    fi
    
    printf "\n"
    
    if [[ "$CHECKS_FAILED" -gt 0 && "$FIX_MODE" != "true" ]]; then
        printf "  ${GREY:-}Tipp: Führe 'SOT doctor --fix' aus für automatische Reparatur${NC:-}\n"
        printf "\n"
    fi
}

# =============================================================================
# Hauptausführung
# =============================================================================

main() {
    if [[ "$SUMMARY_MODE" != "true" ]]; then
        printf "\n"
        printf "  %s╔═══════════════════════════════════════════════════════════╗%s\n" "${BOLD:-}" "${NC:-}"
        printf "  %s║%s     %s🏥 SOT Doctor%s — System Health Check                  %s║%s\n" "${BOLD:-}" "${NC:-}" "${CYAN:-}" "${NC:-}" "${BOLD:-}" "${NC:-}"
        printf "  %s╚═══════════════════════════════════════════════════════════╝%s\n" "${BOLD:-}" "${NC:-}"
    fi
    
    # Alle Checks ausführen
    check_sot_installation
    check_dependencies
    check_configuration
    check_modules
    check_git_status
    check_permissions
    
    # Zusammenfassung anzeigen
    show_summary
    
    # Exit-Code basierend auf Ergebnis
    if [[ "$CHECKS_FAILED" -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
