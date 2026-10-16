import os
import logging
from flask import Flask, request, jsonify
from fastembed import TextEmbedding

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
DIMENSIONS = 384

app = Flask(__name__)

# Global model reference — loaded at startup
model = None


def load_model():
    global model
    cache_dir = os.environ.get("FASTEMBED_CACHE_DIR", "/app/models")
    logger.info(f"Loading model {MODEL_NAME} from cache_dir={cache_dir}...")
    model = TextEmbedding(model_name=MODEL_NAME, cache_dir=cache_dir)
    # Warm up with a dummy embedding to ensure model is fully loaded
    list(model.embed(["warmup"]))
    logger.info(f"Model {MODEL_NAME} loaded and ready ({DIMENSIONS} dimensions)")


@app.route("/health", methods=["GET"])
def health():
    if model is None:
        return jsonify({"status": "loading"}), 503
    return jsonify({
        "status": "ok",
        "model": MODEL_NAME,
        "dimensions": DIMENSIONS,
    })


@app.route("/embed", methods=["POST"])
def embed():
    if model is None:
        return jsonify({"error": "Model not loaded yet"}), 503

    data = request.get_json(silent=True)
    if data is None or "texts" not in data:
        return jsonify({"error": "Request body must be JSON with a 'texts' array"}), 400

    texts = data["texts"]
    if not isinstance(texts, list):
        return jsonify({"error": "'texts' must be an array of strings"}), 400

    if len(texts) == 0:
        return jsonify({"embeddings": []})

    for i, t in enumerate(texts):
        if not isinstance(t, str):
            return jsonify({"error": f"texts[{i}] must be a string"}), 400

    embeddings = [vec.tolist() for vec in model.embed(texts)]
    return jsonify({"embeddings": embeddings})


# Load model at import time so gunicorn preloads it
load_model()
