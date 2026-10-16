# home-assistant

Home Assistant Container, pinned to a specific release because HA ships breaking changes monthly.

- **Host networking** for mDNS/SSDP/DHCP discovery and Bluetooth. Instead of `privileged: true` it gets only `NET_ADMIN`, `NET_RAW` and the D-Bus socket.
- **Tailnet only.** There are no Traefik labels. `stacks/traefik/conf.d/home-assistant.yml` routes `ha.lucask.dev` on the `tailnet` entrypoint to the host's address on the `web` bridge, behind an IP allowlist for Tailscale's address ranges. The DNS record is a manual DNS-only A record pointing at the Pi's Tailscale IP, so the name does not lead anywhere reachable from the internet.
- **Part of the monitoring loop.** Alloy scrapes HA's Prometheus endpoint with a long-lived token. Alertmanager delivers alerts to an HA webhook automation, which sends them as push notifications.
- **Dashboard as code.** `dashboards/build.sh` runs `dashboards/zuhause.py` inside the container. The script reads the Portainer integration's container entities over the websocket API and generates a Mushroom dashboard: a status card per container, grouped by category, with a hold-to-restart action that asks for confirmation. Containers running at build time count as expected; stopped ones are shown as parked. The published script is trimmed to the homelab parts.

`config/` (including `.storage/` and `secrets.yaml`) is never committed.
