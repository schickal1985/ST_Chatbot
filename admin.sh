#!/bin/bash

# ==============================================================================
# ST_Chatbot Admin & Debug Tool
# ==============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

INSTALL_DIR="$HOME/ST_Chatbot"
cd "$INSTALL_DIR" || exit 1

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}      Star Trek SOUL Chatbot - Admin Tool        ${NC}"
echo -e "${BLUE}=================================================${NC}"

if [ ! -f .env ]; then
    echo -e "${RED}Fehler: Keine .env Konfigurationsdatei gefunden.${NC}"
    echo "Bitte führe zuerst das install.sh Skript aus."
    exit 1
fi

source .env

echo "1) 🤖 Token & Bot-Status prüfen (Telegram API Test)"
echo "2) 📝 Live-Logs ansehen (Fehlersuche)"
echo "3) 🔑 Telegram Token oder Modell ändern"
echo "4) 🔄 Bot-Dienst neustarten"
echo "5) ❌ Beenden"
echo ""
read -p "Wähle eine Option [1-5]: " OPTION

case $OPTION in
    1)
        echo -e "\n${YELLOW}Prüfe Telegram Token...${NC}"
        # Telegram API check (getMe)
        API_RESPONSE=$(curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getMe")
        
        # Check if the response contains "ok":true
        if echo "$API_RESPONSE" | grep -q '"ok":true'; then
            BOT_NAME=$(echo "$API_RESPONSE" | grep -o '"first_name":"[^"]*' | cut -d'"' -f4)
            BOT_USERNAME=$(echo "$API_RESPONSE" | grep -o '"username":"[^"]*' | cut -d'"' -f4)
            echo -e "${GREEN}Erfolg! Token ist GÜLTIG.${NC}"
            echo -e "Verbunden als: ${YELLOW}$BOT_NAME (@$BOT_USERNAME)${NC}"
            echo ""
            echo -e "${BLUE}WICHTIGER HINWEIS ZU TELEGRAM BOTS:${NC}"
            echo "Ein Telegram Bot darf aus Spam-Schutz-Gründen NIEMALS von sich aus ein Gespräch beginnen."
            echo "Er kann dir also keine automatische 'Willkommensnachricht' schicken."
            echo -e "Du musst in Telegram den Bot suchen (@$BOT_USERNAME) und ${GREEN}/start${NC} drücken oder ihm eine Nachricht schreiben."
        else
            echo -e "${RED}Fehler! Der Token ist UNGÜLTIG oder blockiert.${NC}"
            echo "Telegram API Antwort:"
            echo "$API_RESPONSE"
        fi
        ;;
    2)
        echo -e "\n${YELLOW}Zeige die letzten 50 Log-Einträge an (Drücke STRG+C zum Beenden)...${NC}"
        sudo journalctl -u st_chatbot -n 50 -f
        ;;
    3)
        echo -e "\n${YELLOW}Konfiguration (.env) bearbeiten:${NC}"
        nano .env
        echo -e "${GREEN}Änderungen gespeichert. Starte den Bot neu...${NC}"
        sudo systemctl restart st_chatbot
        ;;
    4)
        echo -e "\n${YELLOW}Starte den Chatbot-Dienst neu...${NC}"
        sudo systemctl restart st_chatbot
        echo -e "${GREEN}Erledigt.${NC}"
        ;;
    5)
        echo "Beendet."
        exit 0
        ;;
    *)
        echo "Ungültige Option."
        ;;
esac
