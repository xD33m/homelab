#!/bin/bash
# Keep the CrowdSec hub current.
#
# Why this exists: the container entrypoint only runs `cscli hub update/upgrade`
# at START. A container that stays up for months therefore runs increasingly
# stale vpatch-* / scenario rules. That mattered little while AppSec was
# inactive; now that AppSec blocks inline on those rules, stale rules mean
# missed CVEs.
#
# AppSec and parser rules are loaded at datasource init, so the container has to
# be restarted for an upgrade to take effect - we only do that if something
# actually changed. The traefik bouncer is configured fail-open
# (crowdsecAppsecUnreachableBlock: false), so the ~20s restart does not 503 the
# stack; the host firewall bouncer and Cloudflare keep enforcing throughout.
set -uo pipefail

DOCKER=/usr/bin/docker
LOG=${LOG:-$HOME/logs/crowdsec-hub-upgrade.log}
mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1

echo "=== $(date -Is) ==="

if ! $DOCKER exec crowdsec cscli hub update; then
    echo "hub update failed - aborting, will retry next run"
    exit 1
fi

out=$($DOCKER exec crowdsec cscli hub upgrade 2>&1)
echo "$out"

if echo "$out" | grep -qE '^(downloading|updating) '; then
    echo "--> content changed, restarting crowdsec to reload rules"
    $DOCKER restart crowdsec
    sleep 20
    $DOCKER exec crowdsec cscli metrics show appsec 2>&1 | head -8
else
    echo "--> nothing changed, no restart needed"
fi

# keep this log from growing without bound
tail -n 2000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
