#!/usr/bin/env bash
set -euo pipefail

DEV="/sys/bus/usb/devices/3-4/authorized"

if [[ ! -r "$DEV" ]]; then
    printf '{"text":"󰄀","alt":"unavailable","class":"off","tooltip":"Webcam unavailable"}\n'
    exit 0
fi

state=$(<"$DEV")
if [[ "${1:---status}" == "--toggle" ]]; then
    target=1
    [[ "$state" == "1" ]] && target=0
    if ! printf '%s\n' "$target" | sudo -n tee "$DEV" >/dev/null; then
        notify-send --urgency=normal "Webcam" "Could not change webcam power." || true
    fi
    state=$(<"$DEV")
fi

if [[ "$state" == "1" ]]; then
    printf '{"text":"","alt":"on","class":"on","tooltip":"Webcam: on (click to disable)"}\n'
else
    printf '{"text":"󰄀","alt":"off","class":"off","tooltip":"Webcam: off (click to enable)"}\n'
fi
