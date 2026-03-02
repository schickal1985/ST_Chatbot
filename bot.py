import os
import logging
from telegram import Update
from telegram.ext import ApplicationBuilder, ContextTypes, CommandHandler, MessageHandler, filters
import requests
from dotenv import load_dotenv

# Konfiguration des Loggings
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Umgebungsvariablen laden
load_dotenv()
TELEGRAM_TOKEN = os.getenv("TELEGRAM_TOKEN")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "gemma:2b")
OLLAMA_API_URL = os.getenv("OLLAMA_API_URL", "http://localhost:11434/api/generate")

# Die "Seele" des Bots (System Prompt) laden
def load_system_prompt():
    prompt_path = os.path.join(os.path.dirname(__file__), "SOUL.md")
    try:
        with open(prompt_path, "r", encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        logger.warning("SOUL.md wurde nicht gefunden! Verwende Fallback-Prompt.")
        return "Du bist eine KI, die auf den Werten der Föderation und dem Star Trek Optimismus basiert."

SYSTEM_PROMPT = load_system_prompt()

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Sende eine Begrüßungsnachricht, wenn der Nutzer /start eingibt."""
    welcome_text = (
        "🖖 Grüße, Reisender!\n\n"
        "Ich bin eine KI, deren Verhalten vom 'Sinn, Geist und der Seele der Sternenflotte' geprägt ist. "
        "Meine Mission ist es, dir mit Radikaler Empathie, Vernunft und Optimismus zur Seite zu stehen.\n\n"
        "Wie darf ich dir heute behilflich sein?"
    )
    await context.bot.send_message(chat_id=update.effective_chat.id, text=welcome_text)

async def respond(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Verarbeite eingehende Textnachrichten und leite sie an Ollama weiter."""
    user_message = update.message.text
    chat_id = update.effective_chat.id
    
    # Zeige "Tippt..." Aktion an
    await context.bot.send_chat_action(chat_id=chat_id, action='typing')
    
    # Payload für die lokale Ollama-Instanz vorbereiten
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": user_message,
        "system": SYSTEM_PROMPT,
        "stream": False,
        "keep_alive": "24h",  # Hält das Modell im Speicher für schnelle Antworten
        "options": {
            "num_ctx": 2048   # Begrenzt das Context Window (RAM-sparend für kleine VPS)
        }
    }
    
    try:
        # Anfrage an Ollama senden (Timeout auf 5 Minuten erhöht für große Modelle)
        response = requests.post(OLLAMA_API_URL, json=payload, timeout=300)
        response.raise_for_status()
        result = response.json()
        
        # Antwort extrahieren
        bot_reply = result.get("response", "Entschuldigung, meine Sensoren empfangen keine klare Antwort.")
    except requests.exceptions.Timeout:
        bot_reply = "Der Subraum-Kanal ist überlastet (Timeout). Die KI hat mehr als 5 Minuten zum Nachdenken gebraucht."
    except Exception as e:
        logger.error(f"Fehler bei der Verbindung zu Ollama: {e}")
        bot_reply = "Es gab eine Störung im lokalen Kommunikationsnetz. Ich kann die Datenbank (Ollama) derzeit nicht erreichen."
        
    # Antwort an Telegram zurückschicken
    await context.bot.send_message(chat_id=chat_id, text=bot_reply)

if __name__ == '__main__':
    if not TELEGRAM_TOKEN:
        logger.error("TELEGRAM_TOKEN fehlt in der .env Datei. Bitte konfigurieren!")
        exit(1)
        
    # Telegram Bot Anwendung bauen
    application = ApplicationBuilder().token(TELEGRAM_TOKEN).build()
    
    # Handler registrieren
    start_handler = CommandHandler('start', start)
    message_handler = MessageHandler(filters.TEXT & (~filters.COMMAND), respond)
    
    application.add_handler(start_handler)
    application.add_handler(message_handler)
    
    logger.info("Star Trek SOUL Chatbot wird hochgefahren...")
    # Bot starten und auf Nachrichten warten
    application.run_polling()
