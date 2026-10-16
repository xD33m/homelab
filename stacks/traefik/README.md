# traefik

The reverse proxy every web service sits behind, plus `cloudflare-companion`, which keeps Cloudflare DNS in sync with Traefik labels.

| File | What it does |
|---|---|
| `compose.yaml` | Traefik and cloudflare-companion. Traefik reads Docker through `docker-socket-proxy` (in `stacks/monitoring`), not the raw socket. |
| `traefik.yml` | Static config: entrypoints (`http` redirects to `https`, `https` for tunnel traffic, `tailnet` for Tailscale clients, `traefik` for ping and metrics), the Cloudflare DNS-01 wildcard resolver, JSON access logs, Prometheus metrics, and two plugins: `traefik-oidc-auth` and the CrowdSec bouncer. |
| `conf.d/traefik_dynamic_default.yml` | Shared middlewares and the chains routers pick from (`secured`, `secured-auth`, `secured-ws`, `tailnet-secured` and others), TLS options, and a priority-1 catch-all router that returns 503 for unknown hosts. |
| `conf.d/home-assistant.yml` | File-provider route for Home Assistant, which runs on the host network, so it cannot be routed by container labels. Tailnet only. |
| `conf.d/crowdsec_bouncer.yml.example` | The shape of the bouncer middleware. The real file is gitignored because it holds the LAPI key. |
| `entrypoint.sh` | Tails the log files to stdout and rotates them in the background (10 MB, 3 files kept), then `exec`s Traefik so it stays PID 1. |

## How a service gets published

1. Join the external `web` network.
2. Add labels: `traefik.enable=true`, an `https` entrypoint, an explicit ``Host(`name.lucask.dev`)`` rule and a middleware chain from `conf.d`.
3. `docker compose up -d`. cloudflare-companion sees the `Host()` rule and creates a proxied CNAME to the tunnel a few seconds later.

The explicit `Host()` rule matters. `defaultRule` would route `<service>.lucask.dev` anyway, but the companion reads labels, not Traefik's computed routers, so a router without its own rule gets no DNS record.

## Not in this repo

- `cloudflare-companion/cloudflare-companion.py`: a patched copy of the upstream script from the `tiredofit/traefik-cloudflare-companion:7.4.0` image. Upstream only reads the legacy `status`/`id` event fields, which newer Docker API versions no longer send, so it never noticed new containers. The patch also reads `Action`/`Actor.ID`. It is upstream code, so it is not republished here.
- `acme/acme.json`, `logs/` and `plugins-storage/` are runtime state.
- Routes and auth middlewares for personal apps that are not part of this public copy.
