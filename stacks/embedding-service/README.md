# embedding-service

A small local embedding API, so the agent's memory pipeline does not need a hosted embeddings provider.

- `app.py`: Flask app with `GET /health` and `POST /embed`. A request `{"texts": [...]}` returns `{"embeddings": [[...]]}` with 384 floats per text. It uses [fastembed](https://github.com/qdrant/fastembed) with `sentence-transformers/all-MiniLM-L6-v2` on ONNX Runtime (CPU).
- `Dockerfile`: `python:3.11-slim`. The model is downloaded at build time, so the first start does not wait for a download. It runs under gunicorn with 1 worker and 2 threads.
- `compose.yaml`: 256 MB / 0.5 CPU, all capabilities dropped, `traefik.enable=false`. It is only reachable from other containers on `web`.
