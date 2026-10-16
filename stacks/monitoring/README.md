# monitoring

Metrics, logs and alerting for the Pi, plus the Docker socket proxy that the other stacks use for container discovery. This stack creates the `grafana-monitoring` network that other stacks join as external.

```
host /proc, /sys, journal ─┐
Docker (via socket proxy) ─┼─► Alloy ──remote_write──► Prometheus ──► Alertmanager ──webhook──► Home Assistant ──► phone push
Traefik, CrowdSec, HA   ───┘     │                         ▲
                                 └──push──► Loki           │
                                              ▲            │
                                              └─ Grafana ──┘
```

| Service | Role |
|---|---|
| `docker-socket-proxy` | Read-only, filtered access to the Docker API (`POST=0`). Traefik, Alloy, CrowdSec, Glances and cloudflare-companion use `tcp://docker-socket-proxy:2375` instead of mounting the socket. |
| `alloy` | One collector instead of node-exporter, cAdvisor and Promtail. Scrapes host and container metrics, Traefik, CrowdSec, Home Assistant and itself, then remote-writes to Prometheus. Ships Docker logs and the systemd journal to Loki. |
| `prometheus` | 30-day / 1 GB retention. It only scrapes itself; everything else arrives via remote write. Loads alerting and recording rules. |
| `alertmanager` | Groups and routes alerts to a Home Assistant webhook, which pushes them to the phone. The webhook URL is the secret, so it is read from a gitignored file (`url_file`). |
| `loki` | 14-day retention, TSDB schema v13, filesystem storage. |
| `grafana` | Datasources and dashboards are provisioned from `grafana/provisioning/`. |

## Notable details

- **Stable `instance` labels.** Alloy relabels node and cAdvisor targets to `instance="pi4"`, so restarting Alloy does not create new series.
- **Feedback loop avoided.** Alloy drops `docker-socket-proxy`'s own logs. Otherwise every discovery poll would produce a log line that Alloy then tails.
- **cAdvisor tuned for the Pi.** Per-container disk usage metrics showed up at about 35% of Alloy's CPU in a profile and nothing used them, so they are disabled. History is kept at 2 minutes.
- **Recording rules** pre-compute dashboard queries (CPU, memory, filesystem, per-container, Traefik rates and p95).
- **Alert rules** cover targets down, disk, memory, CPU, temperature, crash loops, OOM kills, Traefik 5xx ratio, TLS expiry, the observability stack itself, and CrowdSec health. Comments in `prometheus/rules.yml` explain the exclusions. For example, Alloy and Grafana are excluded from the memory-near-limit alert because Go's GOMEMLIMIT keeps them just under their limit by design.
- **Socket proxy log timeout.** The proxy's HAProxy template is overridden to add a `docker-logs` backend with a 24h server timeout. With the default 10 minutes, idle `logs?follow=1` streams were cut, Alloy reconnected and re-sent the last line, and Loki rejected it as too old.

## Gitignored at runtime

`alloy/secrets/` (Home Assistant long-lived token), `alertmanager/secrets/` (webhook URL), `grafana/` data apart from `provisioning/`, and `docker-socket-proxy/haproxy.cfg.template`.

Dashboards included: Traefik traffic, CrowdSec, stack health, Pi system overview, and Docker containers. A Home Assistant dashboard and one other dashboard are not published.
