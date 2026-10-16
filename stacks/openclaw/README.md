# openclaw

Self-hosted AI agent gateway at `openclaw.lucask.dev`, behind PocketID. It is the most hardened container here: read-only root filesystem, tmpfs for `/tmp` and `/run`, all capabilities dropped, `no-new-privileges`, and no host port.

It joins `grafana-monitoring` as well as `web`. Its memory is stored in Qdrant, with vectors from the embedding service. The agent's config, credentials, sessions and workspace are runtime state and are not published. Only the compose file is here.
