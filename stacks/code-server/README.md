# code-server

VS Code in the browser at `code.lucask.dev`, behind PocketID (`secured-relaxed-auth`, because the editor needs a relaxed CSP). The host's dev directory (`DEV_DIR`) is mounted at the same path, so paths inside the editor match the host.

It runs with `PUID=0`/`PGID=0`, which is root in the container. That is convenient for editing anything in the workspace, and it is the main reason the editor sits behind auth.
