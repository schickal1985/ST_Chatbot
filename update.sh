#!/bin/bash

# ==============================================================================
# ST_Chatbot Auto-Updater (via GitHub)
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

INSTALL_DIR="$HOME/ST_Chatbot"

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}        Star Trek SOUL Chatbot Updater           ${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Fehler: Installationsverzeichnis ($INSTALL_DIR) nicht gefunden!${NC}"
    echo "Bitte führe zuerst die Installation via install.sh aus."
    exit 1
fi

cd "$INSTALL_DIR"

echo -e "${YELLOW}[1/3] Hole die neuesten Änderungen von GitHub...${NC}"
# Verwirft lokale Änderungen an den getrackten Dateien (außer .env, die ignoriert wird)
git fetch origin main
git hard reset origin/main || git pull origin main

echo -e "${YELLOW}[2/3] Aktualisiere Python-Abhängigkeiten...${NC}"
if [ -d "venv" ] && [ -f "requirements.txt" ]; then
    source venv/bin/activate
    pip install -r requirements.txt
    deactivate
else
    echo "virtuelles Environment 'venv' nicht gefunden, überspringe Pip-Installation."
fi

echo -e "${YELLOW}[3/3] Starte den Hintergrunddienst neu...${NC}"
if systemctl is-active --quiet st_chatbot; then
    sudo systemctl restart st_chatbot
    echo -e "${GREEN}Dienst 'st_chatbot' wurde erfolgreich neu gestartet.${NC}"
else
    echo "Dienst 'st_chatbot' läuft scheinbar nicht. Versuch ihn manuell zu starten mit: sudo systemctl start st_chatbot"
fi

echo ""
echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}Update erfolgreich abgeschlossen! Lebe lang und in Frieden! 🖖${NC}"
echo -e "${BLUE}=================================================${NC}"
