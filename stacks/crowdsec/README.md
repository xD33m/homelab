# crowdsec

Intrusion prevention, enforced in two places:

1. **Traefik**: the bouncer plugin is part of every public `secured*` middleware chain. It pulls decisions from the local API in stream mode, and sends each request to the AppSec (WAF) endpoint on `:7422` for inline inspection.
2. **Cloudflare edge**: `cloudflare-bouncer-worker` pushes ban decisions to a Cloudflare Worker, so banned IPs are blocked before they reach the tunnel.

Detection comes from the Traefik access log (`config/acquis.yaml`) and the AppSec datasource (`config/acquis.d/appsec.yaml`). The collections installed at start are listed in `COLLECTIONS` in `compose.yaml`.

| File | Notes |
|---|---|
| `config/acquis.yaml` | Reads `/var/log/traefik/access.log`, which is mounted read-only from the traefik stack. |
| `config/acquis.d/appsec.yaml` | Enables the AppSec datasource with `crowdsecurity/appsec-default`. The full OWASP CRS is installed but deliberately not loaded: about 200 extra rules per request is a lot for a Pi 4, and Cloudflare's managed WAF already covers generic OWASP patterns. |
| `config/config.yaml` | Engine config: SQLite with WAL, a 7-day decision flush, and Prometheus metrics on `:6060`, which Alloy scrapes. |
| `hub-upgrade.sh` | The container only runs `cscli hub update/upgrade` when it starts. This script runs both from the host and restarts CrowdSec only when content changed. The bouncer is fail-open, so the roughly 20 s restart does not take sites down. |

Everything else under `config/` (hub index, LAPI and CAPI credentials, the database) is machine-generated or secret, so it is gitignored. The same goes for `bouncer-configs/`.

Alert rules in `stacks/monitoring/prometheus/rules.yml` watch this stack: engine down, AppSec not inspecting, log ingestion stalled, a stale bouncer, and an unusual alert rate.
