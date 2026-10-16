#!/usr/bin/env bash
# Thin Cloudflare API v4 wrapper, for the DNS and tunnel config this host's
# ingress depends on. Everything here is reachable from the dashboard too - the
# point is doing it reproducibly, and from an SSH session.
#
#   ./cf-api.sh dns digimon.lucask.dev        # records shadowing the wildcard
#   ./cf-api.sh zone lucask.dev               # zone id
#   ./cf-api.sh tunnel-config                 # ingress rules the tunnel serves
#   ./cf-api.sh GET  /zones/<zid>/dns_records?per_page=100
#   ./cf-api.sh POST /zones/<zid>/dns_records '{"type":"A","name":"x",...}'
#   ./cf-api.sh DELETE /zones/<zid>/dns_records/<rid>
#
# Credentials are NOT stored here: it reads CF_API_EMAIL / CF_API_KEY from
# ../traefik/.env (gitignored), the same global key traefik already uses for its
# DNS-01 challenges. That key is account-wide; a scoped token (Zone:DNS:Edit)
# would be a tighter fit if this ever grows beyond occasional manual use.
#
# No IDs are hardcoded on purpose - a tracked file with a stale zone or tunnel id
# is worse than one that looks them up. Account and tunnel ids are decoded from
# the tunnel token in ./.env; the zone id is resolved from CF_ZONE by name.
set -euo pipefail
cd "$(dirname "$0")"

CF_ZONE=${CF_ZONE:-lucask.dev}
API=https://api.cloudflare.com/client/v4

CF_ENV_FILE=${CF_ENV_FILE:-../traefik/.env}
[ -r "$CF_ENV_FILE" ] || { echo "ERROR: cannot read $CF_ENV_FILE (CF_API_EMAIL/CF_API_KEY live there)." >&2; exit 1; }
set -a; . "$CF_ENV_FILE"; set +a
: "${CF_API_EMAIL:?not set in $CF_ENV_FILE}" "${CF_API_KEY:?not set in $CF_ENV_FILE}"

api() { # method path [body]
    local m=$1 p=$2 body=${3:-}
    local args=(-s -X "$m" "$API$p"
        -H "X-Auth-Email: $CF_API_EMAIL" -H "X-Auth-Key: $CF_API_KEY"
        -H "Content-Type: application/json")
    [ -n "$body" ] && args+=(--data "$body")
    curl "${args[@]}"
}

# Cloudflare answers HTTP 200 with {"success": false} on rejection, so exiting
# non-zero has to come from the body, not from curl.
show() {
    python3 -c '
import json,sys
d=json.load(sys.stdin)
if isinstance(d,dict) and d.get("success") is False:
    print("FAILED:", json.dumps(d.get("errors"), indent=2), file=sys.stderr); sys.exit(1)
print(json.dumps(d.get("result", d), indent=2))'
}

zone_id() {
    api GET "/zones?name=$1" | python3 -c '
import json,sys
r=json.load(sys.stdin).get("result") or []
if not r: print("no such zone", file=sys.stderr); sys.exit(1)
print(r[0]["id"])'
}

# The tunnel token is base64 JSON: a=account tag, t=tunnel id, s=secret (never
# printed). Decoding beats hardcoding - the ids follow the token if it is rotated.
tunnel_ids() {
    local f=${TUNNEL_ENV_FILE:-./.env}
    [ -r "$f" ] || { echo "ERROR: cannot read $f (CLOUDFLARE_TUNNEL_TOKEN lives there)." >&2; exit 1; }
    ( set -a; . "$f"; set +a
      python3 -c '
import base64,json,os,sys
t=os.environ.get("CLOUDFLARE_TUNNEL_TOKEN")
if not t: print("CLOUDFLARE_TUNNEL_TOKEN not set", file=sys.stderr); sys.exit(1)
d=json.loads(base64.b64decode(t+"="*(-len(t)%4)))
print(d["a"], d["t"])' )
}

case ${1:-} in
    GET|POST|PUT|PATCH|DELETE)
        api "$1" "${2:?path required}" "${3:-}" | show ;;
    zone)
        zone_id "${2:-$CF_ZONE}" ;;
    dns)
        api GET "/zones/$(zone_id "$CF_ZONE")/dns_records?name=${2:?fqdn required}" | python3 -c '
import json,sys
rs=json.load(sys.stdin).get("result") or []
if not rs: print("(no record - served by a wildcard, if anything)")
for r in rs:
    print(r["id"], r["type"], r["name"], "->", r["content"],
          "proxied=%s" % r["proxied"], "ttl=%s" % r["ttl"], r.get("comment") or "")' ;;
    tunnel-config)
        read -r acct tun < <(tunnel_ids)
        api GET "/accounts/$acct/cfd_tunnel/$tun/configurations" | show ;;
    ''|-h|--help|help)
        sed -n '2,17p' "$0" ;;
    *)
        echo "unknown command: $1" >&2; sed -n '2,17p' "$0" >&2; exit 1 ;;
esac
