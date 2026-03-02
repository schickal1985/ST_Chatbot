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
echo -e "${GREEN}        Star Trek Chatbot Installer         ${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

# 1. System aktualisieren & Systemabhängigkeiten installieren
echo -e "${YELLOW}[1/5] Aktualisiere Ubuntu-System (apt-get update & upgrade)...${NC}"
echo -e "Hinweis: Das System wird zunächst komplett auf den neuesten Stand gebracht."
echo -e "         Dies beugt Paket-Konflikten vor, kann aber einen Moment dauern."
sleep 2

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y

echo -e "\n${YELLOW}Installiere benötigte Basis-Programme (Python, Git, Curl)...${NC}"
sudo apt-get install -y python3 python3-pip python3-venv curl git ffmpeg

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
    echo "Klone das ST_Chatbot Repository von GitHub..."
    git clone "https://github.com/schickal1985/ST_Chatbot.git" "$INSTALL_DIR"
else
    echo "Verzeichnis existiert bereits. Überspringe Klonen."
fi

cd "$INSTALL_DIR"

# 4. Architektur-Design abfragen
echo -e "${YELLOW}[4/6] Architektur-Konfiguration${NC}"
echo "Möchtest du, dass der Chatbot alles lokal auf diesem Rechner berechnet,"
echo "oder möchtest du die KI-Berechnungen (Ollama) an einen separaten,"
echo "leistungsstarken PC im Netzwerk (Remote Server) auslagern?"
echo ""
echo "👉 Drücke einfach ENTER, wenn alles normal (lokal) installiert werden soll."
echo "👉 Gib eine IP (z.B. 192.168.178.50) ein, wenn du einen Remote-Ollama Host nutzt."
read -p "Ollama Server IP [Standard: localhost]: " OLLAMA_IP < /dev/tty

OLLAMA_IP=${OLLAMA_IP:-"localhost"}
OLLAMA_PORT="11434"
OLLAMA_BASE_URL="http://${OLLAMA_IP}:${OLLAMA_PORT}"

if [[ "$OLLAMA_IP" == "localhost" || "$OLLAMA_IP" == "127.0.0.1" ]]; then
    echo -e "${GREEN}-> Klassische lokale Installation gewählt.${NC}"
else
    echo -e "${GREEN}-> Remote-Architektur gewählt. KI tickt auf: $OLLAMA_BASE_URL${NC}"
fi

# 5. Bot Konfiguration abfragen
echo -e "\n${YELLOW}[5/6] Bot-Konfiguration${NC}"

# Standard-Modell, gemma:2b ist sehr schnell und gut für erste Tests auf kleinen Servern
if [ -f .env ]; then
    echo -e "${YELLOW}Es existiert bereits eine Konfiguration (.env).${NC}"
    read -p "Möchtest du diese bestehende Konfiguration komplett löschen und neu anlegen? (j/N): " OVERWRITE_ENV < /dev/tty
    if [[ "$OVERWRITE_ENV" =~ ^[Jj] ]]; then
        rm -f .env
        echo "Bestehende .env gelöscht."
    else
        echo -e "${GREEN}Bestehende Konfiguration wird beibehalten.${NC}"
        source .env
    fi
fi

if [ ! -f .env ]; then
    echo "Um den Telegram Bot zu betreiben, brauchst du einen Bot Token."
    echo "Diesen bekommst du direkt in Telegram beim @BotFather."
    read -p "Gib deinen Telegram Bot Token ein: " TELEGRAM_TOKEN < /dev/tty
    
    # System-Check (RAM) für Modell-Empfehlung
    echo -e "\n${YELLOW}Führe System-Check aus (RAM)...${NC}"
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    TOTAL_MEM_GB=$(awk "BEGIN {printf \"%.1f\", $TOTAL_MEM/1024}")
    
    echo -e "Erkannter Arbeitsspeicher: ${GREEN}${TOTAL_MEM_GB} GB RAM${NC}\n"
    
    echo -e "${YELLOW}Welches KI-Modell möchtest du für deinen Server verwenden?${NC}"
    if [ "$TOTAL_MEM" -lt 3500 ]; then
        echo -e "${RED}Achtung: Dein System hat weniger als 4 GB RAM. Das ist das absolute Minimum.${NC}"
        echo -e "💡 Empfehlung: Option 1 (${GREEN}gemma:2b${NC}) oder Option 5 (${GREEN}qwen2:7b${NC} - könnte langsam sein)"
    elif [ "$TOTAL_MEM" -lt 7000 ]; then
        echo -e "Dein System liegt im mittleren Bereich (4-8 GB RAM)."
        echo -e "💡 Empfehlung: Option 1 (${GREEN}gemma:2b${NC} - sehr schnell) oder Option 2 (${GREEN}llama3${NC} - lastet RAM voll aus)"
    elif [ "$TOTAL_MEM" -lt 15000 ]; then
        echo -e "Dein System hat 8-16 GB RAM. Hervorragend für starke Modelle!"
        echo -e "💡 Empfehlung: Option 7 (${GREEN}llama3.1${NC}) oder Option 6 (${GREEN}gemma2${NC})"
    else
        echo -e "Dein System ist ein echtes Biest! Du hast über 16 GB RAM."
        echo -e "💡 Empfehlung: Option 7 (${GREEN}llama3.1${NC}) oder Option 6 (${GREEN}gemma2${NC})"
    fi
    echo ""
    
    # Lade die offizielle Modelli-Liste von Ollama (vereinfacht über cURL + grep)
    # Da das direkte HTML-Parsing auf bash fehleranfällig ist, bieten wir eine solide 
    # vordefinierte Liste aktueller "Best-Ofs" an, die sofort funktionieren.
    echo "1) gemma:2b       (Googles kleines 2B Modell - rasend schnell)"
    echo "2) llama3         (Meta's 8B Modell, stark im Reasoning)"
    echo "3) mistral        (Der Open-Source Klassiker, 7B Parameter)"
    echo "4) phi3           (Microsoft's winziges Modell, 3.8B, sehr gut bei Logik)"
    echo "5) qwen2:7b       (Alibabas 7B Modell, extrem gut in Deutsch)"
    echo "6) gemma2         (Googles neues 9B Modell, extrem hohe Qualität)"
    echo "7) llama3.1       (Meta's neuestes Modell, 8B)"
    echo "8) Manuelle Eingabe (Ein beliebiges anderes Modell von ollama.com eintragen)"
    
    read -p "Wähle eine Option [1-8, Standard: 1]: " MODEL_CHOICE < /dev/tty
    MODEL_CHOICE=${MODEL_CHOICE:-1}
    
    case $MODEL_CHOICE in
        1) OLLAMA_MODEL="gemma:2b" ;;
        2) OLLAMA_MODEL="llama3" ;;
        3) OLLAMA_MODEL="mistral" ;;
        4) OLLAMA_MODEL="phi3" ;;
        5) OLLAMA_MODEL="qwen2:7b" ;;
        6) OLLAMA_MODEL="gemma2" ;;
        7) OLLAMA_MODEL="llama3.1" ;;
        8) 
            read -p "Bitte tippe den genauen Modell-Namen von ollama.com ein: " MANUAL_MODEL < /dev/tty
            OLLAMA_MODEL=${MANUAL_MODEL:-"gemma:2b"}
            ;;
        *) OLLAMA_MODEL="gemma:2b" ;;
    esac
    
    echo -e "${GREEN}Gewähltes Modell: $OLLAMA_MODEL${NC}"
    
    # Erstelle die .env Datei
    echo "TELEGRAM_TOKEN=$TELEGRAM_TOKEN" > .env
    echo "OLLAMA_MODEL=$OLLAMA_MODEL" >> .env
    echo "OLLAMA_API_URL=${OLLAMA_BASE_URL}/api/generate" >> .env
    echo "OLLAMA_EMBED_URL=${OLLAMA_BASE_URL}/api/embeddings" >> .env
    echo "OLLAMA_EMBED_MODEL=nomic-embed-text" >> .env
    echo -e "${GREEN}.env Datei wurde erfolgreich erstellt.${NC}"
fi

# Modelle herunterladen (nur wenn Ollama lokal läuft!)
# Bezieht die frisch genierte env var
source .env
if [[ "$OLLAMA_API_URL" == *"localhost"* || "$OLLAMA_API_URL" == *"127.0.0.1"* ]]; then
    echo -e "${YELLOW}Lade das Chat-Modell ($OLLAMA_MODEL) lokal herunter...${NC}"
    ollama pull "$OLLAMA_MODEL"

    echo -e "${YELLOW}Lade das Embedding-Modell (nomic-embed-text) lokal herunter...${NC}"
    ollama pull nomic-embed-text
else
    echo -e "${YELLOW}Remote-Ollama konfiguriert ($OLLAMA_API_URL).${NC}"
    echo -e "Überspringe lokalen Modell-Download. Bitte stelle sicher, dass die Modelle auf dem Host-Rechner via 'ollama pull $OLLAMA_MODEL' und 'ollama pull nomic-embed-text' manuell heruntergeladen wurden!"
fi

# 6. Python-Umgebung und System-Dienst (systemd)
echo -e "${YELLOW}[6/6] Richte Python-Umgebung und Systemdienst ein...${NC}"

# Virtuelle Umgebung (VENV) erstellen und Pakete installieren
if [ -f "requirements.txt" ]; then
    python3 -m venv venv
    source venv/bin/activate
    
    echo -e "${YELLOW}Prüfe System auf NVIDIA Grafikkarte...${NC}"
    if lspci | grep -i nvidia > /dev/null; then
        echo -e "${GREEN}NVIDIA GPU erkannt! Installiere reguläres PyTorch mit CUDA-Unterstützung für maximale Performance...${NC}"
        pip install torch torchvision torchaudio
    else
        echo -e "${YELLOW}Keine NVIDIA GPU erkannt. Installiere schlanke CPU-Version von PyTorch (spart ca. 4GB Speicherplatz auf VPS Servern!)...${NC}"
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    fi
    
    echo -e "${YELLOW}Installiere restliche Python-Abhängigkeiten...${NC}"
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
Description=Star Trek Chatbot (Telegram Bot mit Ollama)
After=network.target ollama.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
# Kurze Pause einlegen, um sicherzugehen, dass Ollama nach einem unsauberen Reboot komplett hochgefahren ist
ExecStartPre=/bin/sleep 10
ExecStart=$INSTALL_DIR/venv/bin/python bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable st_chatbot
sudo systemctl restart st_chatbot || echo "Konnte Dienst nicht starten. Eventuell fehlen Dateien in $INSTALL_DIR."

# Admin Tool und Auto-Updater ausführbar machen (falls vorhanden)
if [ -f "$INSTALL_DIR/admin.sh" ]; then
    sudo chmod 755 "$INSTALL_DIR/admin.sh"
fi
if [ -f "$INSTALL_DIR/update.sh" ]; then
    sudo chmod 755 "$INSTALL_DIR/update.sh"
fi

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
