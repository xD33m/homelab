# pocket-id

Passkey-based OIDC provider at `pocketid.lucask.dev`, and the login behind every `*-auth` middleware chain in Traefik.

Traefik's `traefik-oidc-auth` plugin (`pocketid-auth` in `stacks/traefik/conf.d/traefik_dynamic_default.yml`) redirects users without a session here, checks the token with PKCE, and passes the user's email to the backend as `X-Forwarded-User`. The plugin's session-cookie key is set explicitly (`OIDC_SECRET_POCKETID`). Without it the plugin falls back to a default secret that is public in its source.

Data (`./data`: database and signing keys) is gitignored and included in the nightly Backrest run.
