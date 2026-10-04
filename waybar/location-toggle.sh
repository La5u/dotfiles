#!/usr/bin/env bash
# Toggle system-wide location access by masking/unmasking GeoClue.
set -u

unit="geoclue.service"

is_disabled() {
    [[ "$(systemctl is-enabled "$unit" 2>/dev/null || true)" == "masked" ]]
}

status() {
    if is_disabled; then
        printf '{"text":"󰍎","class":"off","tooltip":"Location access disabled — click to enable"}\n'
    else
        printf '{"text":"","class":"on","tooltip":"Location access enabled — click to disable"}\n'
    fi
}

case "${1:---status}" in
    --toggle)
        if is_disabled; then
            sudo systemctl unmask "$unit" >/dev/null
            # GeoClue normally starts on demand over D-Bus. Starting it here
            # makes location immediately available to existing applications.
            sudo systemctl start "$unit"
        else
            sudo systemctl mask --now "$unit" >/dev/null
        fi
        ;;
    --status)
        status
        ;;
    *)
        printf 'Usage: %s [--status|--toggle]\n' "$0" >&2
        exit 2
        ;;
esac
