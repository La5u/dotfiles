#!/usr/bin/env bash
# Toggle system-wide location access by masking/unmasking GeoClue.
set -u

unit="geoclue.service"

is_disabled() {
    [[ "$(systemctl is-enabled "$unit" 2>/dev/null || true)" == "masked" ]]
}

status() {
    if is_disabled; then
        printf '{"text":"󰍑","class":"off","tooltip":"Location access disabled — click to enable"}\n'
    else
        printf '{"text":"󰍎","class":"on","tooltip":"Location access enabled — click to disable"}\n'
    fi
}

case "${1:---status}" in
    --toggle)
        # Waybar has no terminal for a password prompt, so this needs a
        # NOPASSWD sudoers rule for these exact commands.
        if is_disabled; then
            # GeoClue normally starts on demand over D-Bus. Starting it here
            # makes location immediately available to existing applications.
            sudo -n systemctl unmask "$unit" >/dev/null 2>&1 &&
                sudo -n systemctl start "$unit" >/dev/null 2>&1
        else
            sudo -n systemctl mask --now "$unit" >/dev/null 2>&1
        fi || notify-send --urgency=normal "Location" "Could not change location access." || true
        ;;
    --status)
        status
        ;;
    *)
        printf 'Usage: %s [--status|--toggle]\n' "$0" >&2
        exit 2
        ;;
esac
