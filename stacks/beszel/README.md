# beszel

Lightweight host and container monitoring: the Beszel hub at `beszel.lucask.dev`, plus the agent on the host network reading Docker and D-Bus read-only.

The hub's password login is disabled (`DISABLE_PASSWORD_AUTH`). The router uses `secured-relaxed-sse` with `flushInterval=-1`, so Beszel's server-sent events stream through Traefik without buffering.
