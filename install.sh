#!/bin/bash

# ==============================================================================
# ST_Chatbot Ein-Klick-Installation für Ubuntu / Debian
# ==============================================================================

set -e

# Farben für Output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}        Star Trek SOUL Chatbot Installer         ${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

# 1. Systemabhängigkeiten installieren
echo -e "${YELLOW}[1/5] Installiere Systemabhängigkeiten...${NC}"
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv curl git

# 2. Ollama überprüfen und ggf. installieren
echo -e "${YELLOW}[2/5] Prüfe lokales KI-System (Ollama)...${NC}"
if ! command -v ollama &> /dev/null
then
    echo "Ollama nicht gefunden. Starte Installation..."
    curl -fsSL https://ollama.com/install.sh | sh
else
    echo "Ollama ist bereits installiert."
fi

# Ollama-Dienst sicherstellen
sudo systemctl enable ollama || true
sudo systemctl start ollama || true

# 3. Projektverzeichnis einrichten
INSTALL_DIR="$HOME/ST_Chatbot"
echo -e "${YELLOW}[3/5] Richte Projektverzeichnis unter $INSTALL_DIR ein...${NC}"

if [ ! -d "$INSTALL_DIR" ]; then
    echo "Bitte gib jetzt oder später die GitHub Repository URL an, um das Projekt zu klonen:"
    read -p "GitHub Repository URL (oder drücke Enter für leeren Ordner): " REPO_URL
    if [ -n "$REPO_URL" ]; then
        git clone "$REPO_URL" "$INSTALL_DIR"
    else
        mkdir -p "$INSTALL_DIR"
        echo "Leeres Verzeichnis erstellt. Du musst die Projektdateien später manuell dorthin kopieren."
    fi
else
    echo "Verzeichnis existiert bereits. Überspringe Klonen."
fi

cd "$INSTALL_DIR"

# 4. Konfiguration abfragen
echo -e "${YELLOW}[4/5] Konfiguration${NC}"

# Standard-Modell, gemma:2b ist sehr schnell und gut für erste Tests auf kleinen Servern
DEFAULT_MODEL="gemma:2b"

if [ ! -f .env ]; then
    echo "Um den Telegram Bot zu betreiben, brauchst du einen Bot Token."
    echo "Diesen bekommst du direkt in Telegram beim @BotFather."
    read -p "Gib deinen Telegram Bot Token ein: " TELEGRAM_TOKEN
    
    echo ""
    echo "Welches KI-Modell möchtest du verwenden? (z.B. gemma:2b, llama3, mistral)"
    read -p "KI-Modell [Standard: $DEFAULT_MODEL]: " OLLAMA_MODEL
    OLLAMA_MODEL=${OLLAMA_MODEL:-$DEFAULT_MODEL}
    
    # Erstelle die .env Datei
    echo "TELEGRAM_TOKEN=$TELEGRAM_TOKEN" > .env
    echo "OLLAMA_MODEL=$OLLAMA_MODEL" >> .env
    echo "OLLAMA_API_URL=http://localhost:11434/api/generate" >> .env
    echo -e "${GREEN}.env Datei wurde erfolgreich erstellt.${NC}"
else
    echo -e "${GREEN}Konfiguration existiert bereits (.env).${NC}"
    # Modell auslesen, um es zu pullen
    source .env
fi

# Modell herunterladen
echo -e "${YELLOW}Lade das Chat-Modell ($OLLAMA_MODEL) herunter...${NC}"
ollama pull "$OLLAMA_MODEL"

echo -e "${YELLOW}Lade das Embedding-Modell (nomic-embed-text) für das Vektor-Gedächtnis herunter...${NC}"
ollama pull nomic-embed-text

# 5. Python-Umgebung und System-Dienst (systemd)
echo -e "${YELLOW}[5/5] Richte Python-Umgebung und Systemdienst ein...${NC}"

# Virtuelle Umgebung (VENV) erstellen und Pakete installieren
if [ -f "requirements.txt" ]; then
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    deactivate
else
    echo "requirements.txt nicht gefunden! Überspringe Python Paket-Installation."
    echo "Bitte stelle sicher, dass du die Dateien im Verzeichnis hast."
fi

# Systemd Service Datei erstellen
SERVICE_FILE="/etc/systemd/system/st_chatbot.service"

echo "Erstelle systemd Hintergrunddienst..."
sudo bash -c "cat > $SERVICE_FILE" << EOL
[Unit]
Description=Star Trek SOUL Chatbot (Telegram Bot mit Ollama)
After=network.target ollama.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
ExecStart=$INSTALL_DIR/venv/bin/python bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable st_chatbot
sudo systemctl restart st_chatbot || echo "Konnte Dienst nicht starten. Eventuell fehlen Dateien in $INSTALL_DIR."

echo ""
echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}Installation erfolgreich abgeschlossen!${NC}"
echo -e "${BLUE}=================================================${NC}"
echo "Der Chatbot läuft jetzt im Hintergrund."
echo "Du kannst den Status mit folgendem Befehl prüfen:"
echo "  sudo systemctl status st_chatbot"
echo ""
echo "Um Echtzeit-Logs des Bots zu sehen (z.B. für Fehlersuche):"
echo "  sudo journalctl -u st_chatbot -f"
echo ""
echo "Lebe lang und in Frieden! 🖖"
