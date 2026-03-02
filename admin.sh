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
echo -e "${GREEN}      Star Trek Chatbot - Admin Tool        ${NC}"
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
echo "5) 🖥️ System-Check (RAM) & Modell-Empfehlung"
echo "6) ⬇️  Bot updaten (GitHub Auto-Updater)"
echo "7) ❌ Beenden"
echo ""
read -p "Wähle eine Option [1-7]: " OPTION

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
        echo -e "\n${YELLOW}Führe System-Check aus...${NC}"
        # Hole den totalen RAM in MB (Linux)
        TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
        TOTAL_MEM_GB=$(awk "BEGIN {printf \"%.1f\", $TOTAL_MEM/1024}")
        
        echo -e "Erkannter Arbeitsspeicher (RAM): ${GREEN}${TOTAL_MEM_GB} GB${NC}\n"
        
        echo -e "${YELLOW}Modell-Empfehlungen für Ollama auf diesem System:${NC}"
        if [ "$TOTAL_MEM" -lt 3500 ]; then
            echo -e "${RED}Achtung: Dein System hat weniger als 4 GB RAM. Das ist das absolute Minimum.${NC}"
            echo -e "Empfohlen: ${GREEN}qwen2:0.5b${NC} oder ${GREEN}gemma:2b${NC} (Könnte langsam sein)"
        elif [ "$TOTAL_MEM" -lt 7000 ]; then
            echo -e "Dein System hat etwa 4-8 GB RAM. Gut für mittlere Modelle."
            echo -e "Empfohlen: ${GREEN}gemma:2b${NC} (Sehr schnell), ${GREEN}llama3${NC} (Gut, aber braucht fast allen RAM), ${GREEN}phi3${NC}"
        elif [ "$TOTAL_MEM" -lt 15000 ]; then
            echo -e "Dein System hat etwa 8-16 GB RAM. Hervorragend für starke Modelle!"
            echo -e "Empfohlen: ${GREEN}llama3.1${NC}, ${GREEN}gemma2:9b${NC}, ${GREEN}mistral${NC}"
        else
            echo -e "Dein System hat über 16 GB RAM. Du kannst fast alles lokal laufen lassen!"
            echo -e "Empfohlen: ${GREEN}llama3.1${NC}, ${GREEN}gemma2:9b${NC}, oder experimentiere mit großen Modellen wie ${GREEN}command-r${NC} oder ${GREEN}mixtral${NC}"
        fi
        
        echo -e "\n(Um das Modell zu wechseln, starte Option 3 im Admin-Tool und trage den Namen ein)"
        ;;
    6)
        echo -e "\n${YELLOW}Starte Auto-Updater...${NC}"
        if [ -f "$INSTALL_DIR/update.sh" ]; then
            # Führe das Update-Skript explizit mit bash aus, um Ausführungsrechte-Probleme zu umgehen.
            bash "$INSTALL_DIR/update.sh"
            exit 0
        else
            echo -e "${RED}Fehler: update.sh nicht in $INSTALL_DIR gefunden.${NC}"
        fi
        ;;
    7)
        echo "Beendet."
        exit 0
        ;;
    *)
        echo "Ungültige Option."
        ;;
esac
