# SOT Output Style Guide

Dieses Dokument definiert die standardisierte Ausgabe für das SOT-Framework.

## Farbschema

### Primäre Farben

| Farbe | Variable | Verwendung | Beispiel |
|-------|----------|------------|----------|
| **Grün** | `GREEN` / `COLOR_SUCCESS` | Erfolge, Checkmarks | `✓ Installation erfolgreich` |
| **Rot** | `RED` / `COLOR_ERROR` | Fehler, Abbrüche | `✗ Git-Installation fehlgeschlagen` |
| **Gelb** | `YELLOW` / `COLOR_WARNING` | Warnungen, wichtige Hinweise | `⚠ Konfiguration fehlt` |
| **Cyan** | `CYAN` / `COLOR_INFO` | Info-Nachrichten, Progress | `→ Klone Repository` |
| **Magenta** | `MAGENTA` / `COLOR_HIGHLIGHT` | Hervorgehobene Werte | `/opt/SOT` |
| **Weiß** | `WHITE` / `COLOR_LABEL` | Labels, Überschriften | `Konfiguration` |
| **Dimmed** | `DIM` / `COLOR_DIM` | Rahmen, unwichtige Info | Boxen-Linien |

### Legacy-Support (Deprecated)

| Alt | Neu | Hinweis |
|-----|-----|---------|
| `GREY` | `DIM` | Verwende `DIM` für neue Code |
| `PINK` | `MAGENTA` | Verwende `MAGENTA` für neue Code |

## Standard-Funktionen

### Helper-Funktionen (lib/core/helpers.sh)

```bash
# Fehler ausgeben (Rot mit ✗)
err "Fehlertext"
# Ausgabe: ✗ Fehlertext

# Warnung ausgeben (Gelb mit ⚠)
warn "Warnungstext"
# Ausgabe: ⚠ Warnungstext

# Info ausgeben (Cyan mit →)
info "Info-Text"
# Ausgabe: → Info-Text

# Erfolg ausgeben (Grün mit ✓)
success "Erfolgstext"
# Ausgabe: ✓ Erfolgstext

# Wert hervorheben (Magenta)
highlight "wichtiger Wert"
# Ausgabe: wichtiger Wert (in Magenta)

# Label ausgeben (Weiß/Bold)
label "Überschrift"
# Ausgabe: Überschrift (in Weiß)

# Unwichtige Info (Dimmed)
dim "Zusatzinfo"
# Ausgabe: Zusatzinfo (gedimmt)
```

## Verwendungsregeln

### ✅ RICHTIG

```bash
# Info mit hervorgehobenem Wert
info "Erstelle Verzeichnis $(highlight "$CLONE_DIR")"

# Erfolg nach Aktion
success "Repository auf $(highlight "origin/$BRANCH") zurückgesetzt"

# Fehler mit Kontext
err "Settings-Verzeichnis existiert bereits: $(highlight "$SETTINGS_DIR")"

# Label mit strukturierter Ausgabe
label "Konfigurationsübersicht"
echo ""
echo "  Branch:     $(highlight "$BRANCH")"
echo "  Port:       $(highlight "$SSH_PORT")"
```

### ❌ FALSCH

```bash
# Inline-Farben NICHT verwenden
echo -e "${GREY}Branch: ${YELLOW}$BRANCH ${NC}"

# Direkte GREY-Verwendung
echo -e "${GREY}Creating directory...${NC}"

# Keine Symbole in info()
echo -e "${GREEN}✓ Success${NC}"  # Verwende stattdessen success()
```

## Bootstrap-Ausgabe

### Normal-Modus

```bash
# Progress Bar mit Info
[████████████████████░░░░░░░░░] 60% Installiere Dependencies ✓

# Kompakte Abschluss-Meldung
✓ Installation erfolgreich abgeschlossen
→ Konfiguration: /opt/SOT/production/.settings/config.yaml

Nächste Schritte:
  • Extensions installieren: sot ex install aat
  • Verfügbare Extensions: sot ex list
```

### Debug-Modus

```bash
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[3/11] Klone Repository
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

→ Git ist bereits installiert
→ Klone Repository (Branch: production)
✓ Repository erfolgreich geklont

✓ Erfolgreich
```

## Boxen & Rahmen

### Header-Box

```bash
╔══════════════════════════════════════════════════════════════╗
║          SOT Bootstrap - Installation läuft...           ║
╚══════════════════════════════════════════════════════════════╝
```

**Farben:**
- Rahmen: `DIM` (gedimmt)
- "SOT Bootstrap": `GREEN`
- "Installation läuft...": Normal

### Trennlinien

```bash
# Dicke Linie (Debug-Modus)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Farbe: DIM
```

## Strukturierte Ausgabe

### Konfigurationsübersicht

```bash
label "Konfigurationsübersicht"
echo ""
echo "  Branch:                   $(highlight "$BRANCH")"
echo "  Full HostSetup:           $(highlight "${FULL:-false}")"
echo "  Tools:                    $(highlight "$TOOLS")"
echo ""
```

**Stil:**
- Label in Weiß/Bold
- Keys: Normal-Text (kein Farbcode)
- Values: `highlight()` (Magenta)
- Einrückung: 2 Spaces
- Alignment: Mit Spaces für bessere Lesbarkeit

### Abschnitte

```bash
label "System & User"
echo ""
echo "  system_name:              $(highlight "$SYSTEM_NAME")"
echo "  username:                 $(highlight "$USERNAME")"
echo ""

label "SSH"
echo ""
echo "  ssh_port:                 $(highlight "$SSH_PORT")"
echo ""
```

## Best Practices

### 1. Konsistente Icons

```bash
✓ → Erfolg (success)
✗ → Fehler (err)
⚠ → Warnung (warn)
→ → Info/Progress (info)
```

### 2. Wert-Highlighting

```bash
# Pfade, Dateinamen, wichtige Werte
info "Erstelle $(highlight "/opt/SOT")"

# Befehle
echo "  Befehle anzeigen: $(highlight "sot")"
```

### 3. Spacing

```bash
# Nach Label: Leerzeile
label "Überschrift"
echo ""

# Zwischen Abschnitten: Leerzeile
echo "  key: value"
echo ""
label "Nächster Abschnitt"
```

### 4. Alignment

```bash
# Mit Spaces für Alignment
echo "  short_key:                $(highlight "$VALUE")"
echo "  very_long_key_name:       $(highlight "$VALUE")"
```

### 5. Debug vs Normal

```bash
# Debug: Detaillierte Ausgabe
if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
    label "Vollständige Konfiguration"
    # ... alle Details
else
    # Normal: Kompakte Ausgabe
    success "Installation erfolgreich"
    info "Konfiguration: $(highlight "$CONFIG_FILE")"
fi
```

## Migration von altem Code

### Ersetzen: GREY → Semantische Funktion

```bash
# Alt
echo -e "${GREY}Creating directory...${NC}"

# Neu
info "Erstelle Verzeichnis"
```

### Ersetzen: Inline-YELLOW → highlight()

```bash
# Alt
info "Path: ${YELLOW}$PATH${NC}"

# Neu
info "Path: $(highlight "$PATH")"
```

### Ersetzen: Direkte Farben → Helper-Funktionen

```bash
# Alt
echo -e "${GREEN}Success!${NC}"

# Neu
success "Success!"
```

## Checkliste für neue Features

- [ ] Verwende `info()`, `success()`, `err()`, `warn()` statt direkter echo-Befehle
- [ ] Verwende `highlight()` für Werte/Pfade/Befehle
- [ ] Verwende `label()` für Überschriften
- [ ] Verwende `DIM` statt `GREY` für Rahmen
- [ ] Verwende semantische Color-Variablen (`COLOR_SUCCESS`, `COLOR_INFO`, etc.)
- [ ] Keine inline-Farbcodes in echo-Befehlen
- [ ] Konsistente Icons (✓ ✗ ⚠ →)
- [ ] Strukturiertes Layout mit Einrückung
- [ ] Debug-Modus berücksichtigen

## Beispiel: Vollständiger Task

```bash
task_clone_repository() {
    # Check Git
    if ! command -v git &> /dev/null; then
        info "Git wird installiert..."
        sudo apt-get update && sudo apt-get install -y git
        
        if ! command -v git &> /dev/null; then
            err "Git-Installation fehlgeschlagen"
            exit 1
        fi
        success "Git erfolgreich installiert"
    else
        info "Git ist bereits installiert"
    fi
    
    # Clone repository
    info "Klone Repository (Branch: $(highlight "$BRANCH"))"
    if sudo git clone -b "$BRANCH" "$REPO_URL" "$CLONE_DIR"; then
        success "Repository erfolgreich geklont"
    else
        err "Repository konnte nicht geklont werden"
        exit 1
    fi
}
```

## Siehe auch

- [lib/core/colors.sh](../lib/core/colors.sh) - Farbdefinitionen
- [lib/core/helpers.sh](../lib/core/helpers.sh) - Helper-Funktionen
- [BOOTSTRAP.md](BOOTSTRAP.md) - Bootstrap-Dokumentation
