import os
import logging
from telegram import Update
from telegram.ext import ApplicationBuilder, ContextTypes, CommandHandler, MessageHandler, filters
import requests
from dotenv import load_dotenv
from duckduckgo_search import DDGS
import chromadb
from chromadb.api.types import Documents, EmbeddingFunction, Embeddings
import tempfile
import pypdf
import docx
import pandas as pd

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
OLLAMA_EMBED_URL = os.getenv("OLLAMA_EMBED_URL", "http://localhost:11434/api/embeddings")
OLLAMA_EMBED_MODEL = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")

# --- 1. System Prompt ---
def load_system_prompt():
    prompt_path = os.path.join(os.path.dirname(__file__), "SOUL.md")
    try:
        with open(prompt_path, "r", encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        logger.warning("SOUL.md wurde nicht gefunden! Verwende Fallback-Prompt.")
        return "Du bist eine hilfreiche KI."

SYSTEM_PROMPT = load_system_prompt()

# --- 2. Vektor-Gedächtnis (ChromaDB + Ollama Embeddings) ---
class OllamaEmbeddingFunction(EmbeddingFunction):
    """Nutzt die lokale Ollama-Instanz zur Erstellung von Vektor-Embeddings."""
    def __call__(self, input: Documents) -> Embeddings:
        embeddings = []
        for text in input:
            try:
                response = requests.post(OLLAMA_EMBED_URL, json={
                    "model": OLLAMA_EMBED_MODEL,
                    "prompt": text
                }, timeout=30)
                response.raise_for_status()
                embeddings.append(response.json()["embedding"])
            except Exception as e:
                logger.error(f"Fehler beim Embedding von Text via Ollama: {e}")
                # Fallback: Leerer Vektor, falls das Modell nicht geladen ist (verhindert Crash, aber ist ungenau)
                # Besser: Fehler werfen oder Dummy-Vektor
                embeddings.append([0.0] * 768) 
        return embeddings

# Initialisiere ChromaDB im Ordner 'chroma_data'
DB_PATH = os.path.join(os.path.dirname(__file__), "chroma_data")
chroma_client = chromadb.PersistentClient(path=DB_PATH)
embedding_func = OllamaEmbeddingFunction()

# Collection für unser Gedächtnis
collection = chroma_client.get_or_create_collection(
    name="chat_history", 
    embedding_function=embedding_func
)

# --- 3. Web-Suche ---
def perform_web_search(query: str, max_results=3) -> str:
    """Führt eine DuckDuckGo-Suche aus und gibt die Ergebnisse als Text zurück."""
    try:
        with DDGS() as ddgs:
            # duckduckgo_search requires max_results to be explicitly passed, 
            # and might block or throw if the network fails.
            results = ddgs.text(query, max_results=max_results)
            if not results:
                return "Keine Suchergebnisse gefunden."
            
            search_text = "Aktuelle Informationen aus dem Internet (DuckDuckGo):\n"
            for r in results:
                search_text += f"- {r.get('title', '')}: {r.get('body', '')}\n"
            return search_text
    except Exception as e:
        logger.error(f"Kritischer Fehler bei der Web-Suche aus DDGS: {e}")
        return ""

def needs_web_search(text: str) -> bool:
    """Simpler heuristischer Check, ob die Frage eine Web-Suche erfordert."""
    trigger_words = ["suche", "heute", "aktuell", "nachrichten", "wetter", "news", "neuigkeiten", "wer ist", "was ist das", "internet"]
    text_lower = text.lower()
    return any(word in text_lower for word in trigger_words)

# --- 4. Telegram Bot Handler ---
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    welcome_text = (
        "Hallo! 👋\n\n"
        "Ich bin hier, um dich bestmöglich zu unterstützen – sei es bei Fragen, "
        "Problemen oder einfach für einen verständnisvollen Dialog. Ich höre dir zu und helfe dir gerne.\n\n"
        "Wie darf ich dir heute behilflich sein?"
    )
    try:
        await context.bot.send_message(chat_id=update.effective_chat.id, text=welcome_text)
    except Exception as e:
        logger.error(f"Fehler beim Senden der Start-Nachricht: {e}")

async def respond(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_message = update.message.text
    chat_id = str(update.effective_chat.id)
    message_id = str(update.message.message_id)
    
    await context.bot.send_chat_action(chat_id=chat_id, action='typing')
    
    # 1. Gedächtnis abrufen (RAG)
    try:
        memory_results = collection.query(
            query_texts=[user_message],
            n_results=3,
            where={"chat_id": chat_id} # Nur Erinnerungen aus diesem Chat!
        )
        memory_context = ""
        if memory_results['documents'] and memory_results['documents'][0]:
            memory_context = "Erinnerungen aus bisherigen Unterhaltungen:\n"
            for doc in memory_results['documents'][0]:
                memory_context += f"- {doc}\n"
            memory_context += "\n"
    except Exception as e:
        logger.error(f"Fehler beim Abrufen des Gedächtnisses: {e}")
        memory_context = ""

    # 2. Web-Suche auslösen (falls nötig)
    search_context = ""
    try:
        if needs_web_search(user_message):
            logger.info(f"Führe Web-Suche aus für: {user_message}")
            result = perform_web_search(user_message)
            if result:
                search_context = result + "\n\n"
    except Exception as e:
         logger.error(f"Fehler in der Web-Such-Logik: {e}")

    # 3. Prompt zusammenbauen
    # Den System-Prompt um die dynamischen Kontext-Blöcke erweitern
    dynamic_system_prompt = SYSTEM_PROMPT + "\n\n---\n" + memory_context + search_context + "Nutze diese zusätzlichen Informationen nur, wenn sie für die Beantwortung der aktuellen Frage relevant sind."
    
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": user_message,
        "system": dynamic_system_prompt,
        "stream": False,
        "keep_alive": "24h",
        "options": {
            "num_ctx": 4096 # Etwas erhöhen, da wir durch Suchergebnisse und Gedächtnis mehr Text übergeben!
        }
    }
    
    try:
        response = requests.post(OLLAMA_API_URL, json=payload, timeout=300)
        response.raise_for_status()
        bot_reply = response.json().get("response", "Entschuldigung, ich konnte gerade keine klare Antwort formulieren.")
        
        # 4. Verlauf ins Gedächtnis speichern!
        try:
            # Wir speichern sowohl die Frage als auch die Antwort als ein "Wissenspaket"
            interaction_text = f"Nutzer sagte: {user_message} | Ich antwortete: {bot_reply}"
            collection.add(
                documents=[interaction_text],
                metadatas=[{"chat_id": chat_id, "type": "interaction"}],
                ids=[f"msg_{chat_id}_{message_id}"]
            )
        except Exception as e:
            logger.error(f"Konnte Interaktion nicht ins Gedächtnis speichern: {e}")

    except requests.exceptions.Timeout:
        bot_reply = "Entschuldige bitte, ich habe für die Antwort etwas zu lange gebraucht (Timeout). Frag mich gerne noch einmal."
        logger.error("Ollama API Timeout erreicht!")
    except Exception as e:
        logger.error(f"Fehler bei der Verbindung zu Ollama oder RAG Verarbeitung: {e}")
        bot_reply = "Es tut mir leid, es gab gerade ein kleines technisches Problem bei mir. Ich bin gleich wieder einsatzbereit."
        
    try:
        await context.bot.send_message(chat_id=chat_id, text=bot_reply)
    except Exception as e:
        logger.error(f"Fehler beim Senden der Telegram-Nachricht: {e}")

async def handle_document(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Verarbeitet hochgeladene Dokumente und fügt sie in das RAG-Gedächtnis ein."""
    file = await update.message.document.get_file()
    file_name = update.message.document.file_name
    chat_id = str(update.effective_chat.id)
    
    await context.bot.send_message(chat_id=chat_id, text=f"Lade '{file_name}' herunter und lese die Inhalte...")
    
    with tempfile.NamedTemporaryFile(delete=False, suffix=f"_{file_name}") as tmp_file:
        tmp_path = tmp_file.name
        
    try:
        await file.download_to_drive(tmp_path)
        
        extracted_text = ""
        # 1. Dateiformat erkennen und Text extrahieren
        if file_name.lower().endswith(".pdf"):
            reader = pypdf.PdfReader(tmp_path)
            for page in reader.pages:
                extracted_text += page.extract_text() + "\n"
        elif file_name.lower().endswith(".docx"):
            doc = docx.Document(tmp_path)
            for para in doc.paragraphs:
                extracted_text += para.text + "\n"
        elif file_name.lower().endswith(".xlsx") or file_name.lower().endswith(".csv"):
            if file_name.lower().endswith(".csv"):
                df = pd.read_csv(tmp_path)
            else:
                df = pd.read_excel(tmp_path)
            extracted_text = df.to_string()
        elif file_name.lower().endswith(".txt") or file_name.lower().endswith(".md"):
            with open(tmp_path, "r", encoding="utf-8", errors="ignore") as f:
                extracted_text = f.read()
        else:
            await context.bot.send_message(chat_id=chat_id, text=f"Dieses Dateiformat ({file_name}) wird noch nicht unterstützt.")
            return

        if not extracted_text.strip():
            await context.bot.send_message(chat_id=chat_id, text=f"Ich konnte leider keinen lesbaren Text in '{file_name}' finden.")
            return
            
        # 2. Text in sinnvolle Chunks zerlegen (für bessere Vektor-Suche)
        chunk_size = 1500
        words = extracted_text.split()
        chunks = []
        current_chunk = []
        current_len = 0
        
        for word in words:
            current_chunk.append(word)
            current_len += len(word) + 1
            if current_len >= chunk_size:
                chunks.append(" ".join(current_chunk))
                current_chunk = []
                current_len = 0
        if current_chunk:
            chunks.append(" ".join(current_chunk))

        # 3. Chunks in ChromaDB speichern
        ids = [f"doc_{chat_id}_{file_name}_{i}" for i in range(len(chunks))]
        metadatas = [{"chat_id": chat_id, "source": file_name, "type": "document"} for _ in range(len(chunks))]
        
        collection.add(
            documents=chunks,
            metadatas=metadatas,
            ids=ids
        )
        await context.bot.send_message(chat_id=chat_id, text=f"✅ Die Inhalte von '{file_name}' wurden erfolgreich in mein Gedächtnis übertragen! Du kannst nun Fragen dazu stellen.")
        
    except Exception as e:
        logger.error(f"Fehler bei Dokumentverarbeitung: {e}")
        await context.bot.send_message(chat_id=chat_id, text=f"Es gab einen Fehler beim Verarbeiten von '{file_name}'.")
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

if __name__ == '__main__':
    if not TELEGRAM_TOKEN:
        logger.error("TELEGRAM_TOKEN fehlt in der .env Datei. Bitte konfigurieren!")
        exit(1)
        
    application = ApplicationBuilder().token(TELEGRAM_TOKEN).build()
    
    application.add_handler(CommandHandler('start', start))
    application.add_handler(MessageHandler(filters.TEXT & (~filters.COMMAND), respond))
    application.add_handler(MessageHandler(filters.Document.ALL, handle_document))
    
    logger.info("Star Trek SOUL Chatbot wird hochgefahren...")
    application.run_polling()
