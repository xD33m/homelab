# cloudflare-tunnel

The only way in from the internet. `cloudflared` opens an outbound connection to Cloudflare's edge and forwards requests to Traefik over the `web` network, so no port is forwarded on the router.

The tunnel's public-hostname rules are wildcards for both zones, but DNS is not: every hostname gets its own proxied CNAME, created by `cloudflare-companion` in the traefik stack. An undeclared subdomain returns NXDOMAIN and never reaches the tunnel.

`cf-api.sh` is a small Cloudflare API v4 wrapper for the DNS and tunnel config this ingress depends on: look up zone ids, list the records for a hostname, dump the tunnel's ingress rules, or send a raw `GET`/`POST`/`DELETE`. It hardcodes no ids. It reads the API key from `../traefik/.env` and decodes the account and tunnel ids from the tunnel token.

```bash
./cf-api.sh zone lucask.dev
./cf-api.sh dns grafana.lucask.dev
./cf-api.sh tunnel-config
```
