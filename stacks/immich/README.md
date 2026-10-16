# immich

Photo and video backup at `immich.lucask.dev`, based on the upstream compose file.

Changes from upstream:

- `immich-server` joins `web` and gets Traefik labels with the `secured-upload` chain. Postgres, Valkey and machine learning stay on the internal `immich` network.
- The machine-learning container is limited to 1.5 CPUs and 2 GB RAM, so face and CLIP jobs cannot starve the rest of the Pi.

Backups: the Backrest `immich_backup` plan runs `pg_dump` in `immich_postgres` and then snapshots the library into its own restic repo. See `stacks/backrest`.
