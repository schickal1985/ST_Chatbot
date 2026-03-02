# ST_Chatbot (SOUL)

Ein lokaler, auf den Prinzipien der Sternenflotte und dem „Star Trek Optimismus“ basierender KI-Chatbot für Telegram. Die KI ist durch Radikale Empathie, Friedfertigkeit, IDIC (Infinite Diversity in Infinite Combinations) und Optimismus gekennzeichnet.

Dieses Projekt verbindet:
1. Das Telegram Bot-Ökosystem (zur Interaktion über das Smartphone)
2. Ein lokales LLM via [Ollama](https://ollama.com/) (absoluter Datenschutz, 100% lokal ausgeführt)
3. Eine portables Markdown-Manifest (`SOUL.md`), welches der KI ihren Verhaltenscodex aufzwingt.

## Ein-Klick-Installation (Ubuntu / Debian)

Du kannst das komplette System in ca. 3 Minuten vollautomatisch auf einem Ubuntu-Server (z.B. VPS, lokaler Rechner, Raspberry Pi 5) installieren.

Das Setup (inspiriert von Projekten wie OpenWebUI):
- Installiert `Ollama` automatisch, falls nicht vorhanden.
- Lädt das gewünschte Basis-Sprachmodell herunter.
- Fragt im Terminal nach deinem Telegram Bot-Token.
- Richtet den Bot als `systemd`-Dienst ein, damit er nach Abstürzen oder Neustarts automatisch weiterläuft.

**Befehl zur Installation:**
*(Stelle sicher, dass du das Projekt auf Github hast, oder passe die URL an dein Repo an)*

```bash
curl -sL https://raw.githubusercontent.com/schickal1985/ST_Chatbot/main/install.sh | bash
```

*(Wenn du die Datei ausführst, fragt das Script dich nach der Repo URL, deinem Telegram-Token und dem zu verwendenden KI-Modell.)*

## Voraussetzungen & Vorbereitung
1. Du benötigst einen Telegram Bot Token. Öffne dazu Telegram, suche nach dem **@BotFather**, starte ihn mit `/newbot`, gib ihm einen Namen und kopiere den ausgegebenen HTTP API Token.
2. Der Server sollte mindestens 4GB RAM (besser 8GB) haben, wenn die KI schnell lokal antworten soll.

## Manuelle Einrichtung & Portabilität
Das System ist komplett portabel konzipiert. Die Konfiguration läuft rein über eine lokale `.env` Datei und die KI-Persönlichkeit über eine austauschbare Markdown-Datei.

### Lokaler Test (Windows / Mac)
1. Installiere [Ollama](https://ollama.com) für dein System.
2. Lade im Terminal ein Modell herunter: `ollama run gemma:2b`
3. Erstelle eine Datei namens `.env` im Projektordner:
   ```ini
   TELEGRAM_TOKEN=123456789:DeinBotTokenHier
   OLLAMA_MODEL=gemma:2b
   OLLAMA_API_URL=http://localhost:11434/api/generate
   ```
4. Installiere die Python-Bibliotheken:
   ```bash
   pip install -r requirements.txt
   ```
5. Starte den Bot:
   ```bash
   python bot.py
   ```

## Wie beeinflusse ich das Verhalten?
Öffne einfach die [SOUL.md](SOUL.md) und ändere den Text. Sobald der Bot (das Skript `bot.py`) das nächste Mal gestartet wird, lädt er die Instruktionen frisch ein.

## Weiterentwicklung
Aktuell lauscht der Bot nur auf Text und antwortet textlich. Später kann man dies erweitern um:
- Web-UI für einfache Änderungen
- Spracherkennung (Voice Messages in Text)
- Gedächtnis (Memory-Vektor-Datenbanken) für lange Gesprächshistorien.
