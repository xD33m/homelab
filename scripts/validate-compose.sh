#!/usr/bin/env bash
# Validate every stacks/*/compose.yaml with `docker compose config`.
#
# Each stack is rendered with its .env.example values, so this also catches a
# ${VAR} that a compose file uses but .env.example does not document: compose
# only warns about unset variables, and this script turns that warning into a
# failure. A temporary .env is created from .env.example because services with
# `env_file: .env` need the file to exist; it is removed again afterwards.
set -euo pipefail
cd "$(dirname "$0")/.."

status=0
for file in stacks/*/compose.yaml; do
    dir=$(dirname "$file")
    created_env=false
    if [ -f "$dir/.env.example" ] && [ ! -e "$dir/.env" ]; then
        cp "$dir/.env.example" "$dir/.env"
        created_env=true
    fi

    if output=$(cd "$dir" && docker compose -f compose.yaml config -q 2>&1); then
        if grep -qi 'variable is not set' <<<"$output"; then
            echo "FAIL $file (undocumented variable)"
            echo "$output" | sed 's/^/    /'
            status=1
        else
            echo "ok   $file"
        fi
    else
        echo "FAIL $file"
        echo "$output" | sed 's/^/    /'
        status=1
    fi

    if [ "$created_env" = true ]; then
        rm -f "$dir/.env"
    fi
done
exit "$status"
