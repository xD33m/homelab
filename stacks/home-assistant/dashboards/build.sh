#!/usr/bin/env bash
# Rebuild the "Zuhause" dashboard from live Home Assistant data.
# Run on the Pi after adding/removing a stack: ./build.sh
#
# Reuses the long-lived token Alloy scrapes with (piped on stdin, never on the
# command line). The script runs inside the homeassistant container because
# that has aiohttp.
set -euo pipefail
cd "$(dirname "$0")"
TOKEN_FILE=../../monitoring/alloy/secrets/homeassistant_token

docker cp -q zuhause.py homeassistant:/tmp/zuhause.py
trap 'docker exec homeassistant rm -f /tmp/zuhause.py' EXIT
docker exec -i homeassistant python3 /tmp/zuhause.py < "$TOKEN_FILE"
