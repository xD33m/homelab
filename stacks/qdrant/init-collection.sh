#!/bin/bash
# init-collection.sh — Idempotently create or recreate the openclaw-memory
# Qdrant collection with 384-dim vectors (all-MiniLM-L6-v2).
#
# Usage: ./init-collection.sh [QDRANT_URL]
#   QDRANT_URL defaults to http://localhost:6333 (or http://qdrant:6333 inside Docker)

set -euo pipefail

QDRANT_URL="${1:-http://qdrant:6333}"
COLLECTION="openclaw-memory"
EXPECTED_DIM=384

echo "=== Qdrant Collection Init ==="
echo "Qdrant URL: ${QDRANT_URL}"
echo "Collection: ${COLLECTION}"
echo "Expected dimensions: ${EXPECTED_DIM}"
echo ""

# Check if collection exists
HTTP_CODE=$(curl -s -o /tmp/qdrant-collection.json -w "%{http_code}" \
  "${QDRANT_URL}/collections/${COLLECTION}")

if [ "$HTTP_CODE" = "200" ]; then
  CURRENT_DIM=$(python3 -c "
import json
with open('/tmp/qdrant-collection.json') as f:
    data = json.load(f)
    params = data.get('result', {}).get('config', {}).get('params', {})
    vectors = params.get('vectors', {})
    # Handle both named and unnamed vector configs
    if isinstance(vectors, dict) and 'size' in vectors:
        print(vectors['size'])
    else:
        print(0)
" 2>/dev/null || echo "0")

  echo "Collection '${COLLECTION}' exists with ${CURRENT_DIM} dimensions."

  if [ "$CURRENT_DIM" = "$EXPECTED_DIM" ]; then
    echo "Dimensions match. No migration needed."
  else
    echo "Dimension mismatch (have ${CURRENT_DIM}, want ${EXPECTED_DIM}). Deleting old collection..."
    curl -sf -X DELETE "${QDRANT_URL}/collections/${COLLECTION}" > /dev/null
    echo "Deleted."
    HTTP_CODE="404"  # Trigger recreation below
  fi
fi

if [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" != "200" ]; then
  echo "Creating collection '${COLLECTION}' with ${EXPECTED_DIM} dimensions..."
  curl -sf -X PUT "${QDRANT_URL}/collections/${COLLECTION}" \
    -H "Content-Type: application/json" \
    -d '{
      "vectors": {
        "size": '"${EXPECTED_DIM}"',
        "distance": "Cosine",
        "on_disk": true
      },
      "hnsw_config": {
        "on_disk": true
      },
      "on_disk_payload": true
    }' > /dev/null
  echo "Collection created."
fi

# Create payload indexes (idempotent — Qdrant ignores if they already exist)
echo ""
echo "Ensuring payload indexes..."

for FIELD in date channel importance; do
  echo "  Creating index on '${FIELD}'..."
  curl -sf -X PUT "${QDRANT_URL}/collections/${COLLECTION}/index" \
    -H "Content-Type: application/json" \
    -d '{
      "field_name": "'"${FIELD}"'",
      "field_schema": "keyword"
    }' > /dev/null
  echo "  ✓ ${FIELD}"
done

echo ""
echo "=== Done ==="

# Verify
echo ""
echo "Verification:"
curl -s "${QDRANT_URL}/collections/${COLLECTION}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
result = data.get('result', {})
config = result.get('config', {}).get('params', {})
vectors = config.get('vectors', {})
status = result.get('status', 'unknown')
points = result.get('points_count', 0)
print(f'  Status: {status}')
print(f'  Dimensions: {vectors.get(\"size\", \"?\")}')
print(f'  Distance: {vectors.get(\"distance\", \"?\")}')
print(f'  On-disk: {vectors.get(\"on_disk\", \"?\")}')
print(f'  Points: {points}')
"
