# qdrant

Vector database for the OpenClaw agent's semantic memory, behind PocketID at `qdrant.lucask.dev`. Limited to 256 MB RAM and 0.5 CPU, with on-disk payloads.

`init-collection.sh` creates the `openclaw-memory` collection idempotently: 384-dimension cosine vectors to match `all-MiniLM-L6-v2` from `stacks/embedding-service`, with vectors and the HNSW index on disk. If the collection already exists with a different dimension, the script recreates it. It also adds keyword payload indexes on `date`, `channel` and `importance`.
