#!/bin/bash
# Farben für die Ausgabe
GREEN='\033[0;32m'
RED='\033[0;31m'
GREY='\033[1;90m'
NC='\033[0m' # Keine Farbe

# Skript zur Installation von Docker und seinen Abhängigkeiten auf Ubuntu/Debian

# Überprüfen, ob Docker bereits installiert ist
if command -v docker &> /dev/null; then
    echo -e "${GREY}Docker is already installed.${NC}"
else
    # Temporären Ordner erstellen
    echo -e "${GREY}Creation of a temporary folder...${NC}"
    TMP_DIR=$(mktemp -d)

    echo -e "${GREY}Download dependent packages..."
    # Update der Paketliste und Installation der Voraussetzungen
    sudo apt-get update
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl 

    echo -e "${GREY}Download Docker installation script...${NC}"
    curl -fsSL https://get.docker.com -o "$TMP_DIR/get-docker.sh"

    # Prüfen, ob die Datei heruntergeladen wurde
    if [ -f "$TMP_DIR/get-docker.sh" ]; then
        echo -e "${GREY}Docker installation script downloaded to: $TMP_DIR/get-docker.sh${NC}"
        echo -e "${GREY}Installation of Docker..."
        sh "$TMP_DIR/get-docker.sh"
    else
        echo -e "${RED}Docker installation script does not exist at: $TMP_DIR/get-docker.sh${NC}"
        echo -e "${RED}Aborting installation.${NC}"
        exit 1
    fi

    # Nach der Nutzung wird der Ordner gelöscht
    echo -e "${GREY}Cleaning up...${NC}"
    rm -rf "$TMP_DIR"
    echo -e "${GREY}Temporary directory deleted.${NC}"
fi

# Überprüfen, ob Docker Compose bereits installiert ist
if command -v docker-compose &> /dev/null; then
    echo -e "${GREY}Docker Compose is already installed.${NC}"
else
    echo -e "${GREY}Installing Docker Compose..."
    sudo apt-get install -y docker-compose
fi

echo -e "${GREY}Script finished.${NC}"
