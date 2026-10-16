#!/bin/sh
set -e

# Create log files if they don't exist (logs dir is writable)
touch /var/log/traefik/traefik.log 2>/dev/null || true
touch /var/log/traefik/access.log 2>/dev/null || true

# Tail them in the background (show last 100 lines for context)
tail -n 100 -F /var/log/traefik/traefik.log /var/log/traefik/access.log 2>/dev/null &

# Log rotation function - optimized for Raspberry Pi
rotate_logs() {
    while true; do
        sleep 600 # Check every 10 minutes (less frequent for Pi)
        for logfile in access.log traefik.log; do
            if [ -f "/var/log/traefik/${logfile}" ]; then
                # Rotate if larger than 10MB (10485760 bytes)
                SIZE=$(stat -c %s "/var/log/traefik/${logfile}" 2>/dev/null || echo 0)
                if [ "$SIZE" -gt 10485760 ]; then
                    echo "$(date) - Rotating ${logfile} (size: $SIZE bytes)"
                    # Keep up to 3 rotated logs
                    rm -f "/var/log/traefik/${logfile}.3" 2>/dev/null || true
                    mv "/var/log/traefik/${logfile}.2" "/var/log/traefik/${logfile}.3" 2>/dev/null || true
                    mv "/var/log/traefik/${logfile}.1" "/var/log/traefik/${logfile}.2" 2>/dev/null || true
                    mv "/var/log/traefik/${logfile}" "/var/log/traefik/${logfile}.1" 2>/dev/null || true
                    # Signal Traefik to reopen logs (PID 1)
                    kill -USR1 1 2>/dev/null || true
                fi
            fi
        done
    done
}

# Start rotation in background
rotate_logs &

# Start Traefik
# exec replaces the shell with traefik, so traefik becomes PID 1
exec traefik --configFile=/etc/traefik/traefik.yml
