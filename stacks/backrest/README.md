# backrest

[Backrest](https://github.com/garethgeorge/backrest) is a web UI and scheduler around restic, served behind PocketID.

It mounts the parent `stacks/` directory at `/host/stacks`, so data any stack keeps in a bind mount is in reach of a plan without extra wiring. It also mounts the Docker socket so hooks can run commands in other containers.

`config/config.json.example` has the plan layout with placeholder credentials:

- **`all_configs`**: nightly at 03:00, the whole `stacks/` tree. Excluded are caches, logs, `.git`, large or live data (the Immich library and Postgres, Home Assistant's live SQLite database) and data covered by its own plan.
- **Per-service plans** at 03:00 for Beszel, code-server, CrowdSec, Gitea, Grafana and Memos data.
- **`immich_backup`**: 04:00, the Immich library into a separate restic repo. Thumbnails and transcoded video are skipped because Immich can regenerate them. A `CONDITION_SNAPSHOT_START` hook runs `pg_dump` in `immich_postgres` first, so the snapshot contains a consistent database dump.
- Retention: the last 14 snapshots per plan.

Both restic repositories live on the Pi itself (`/data/backups` and a folder inside the Immich stack). That protects against mistakes and broken upgrades, not against losing the disk. See the trade-offs in the root README.

Named Docker volumes (Prometheus, Loki, Alertmanager, Portainer, the Immich ML model cache) are not under `stacks/`, so they are not backed up. They hold rebuildable or low-value state.
