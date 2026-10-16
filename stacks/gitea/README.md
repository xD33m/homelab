# gitea

Self-hosted Git (Gitea 1.21.7, pinned) behind the `secured` chain. Data lives in `./gitea` (gitignored) and has its own Backrest plan, without logs, indexers and queues.

SSH is published on host port 2221. The web UI is published on 8888 as well as through the Traefik route.

The public copy fixes one typo in the live file: the `/etc/localtime` mount mode was `rbo` instead of `ro`.
