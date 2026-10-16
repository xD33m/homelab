# portainer

Portainer CE at `portainer.lucask.dev`. The backend speaks HTTPS with a self-signed certificate, so the router uses the `insecureTransport@file` servers transport from Traefik's dynamic config.

Like Glances, it also listens on `127.0.0.1:9443` for Home Assistant's Portainer integration. That integration provides the container entities (state, CPU, memory, restart buttons) the generated dashboard in `stacks/home-assistant/dashboards` is built from.

Portainer mounts the Docker socket read-write, because managing containers is its job.
