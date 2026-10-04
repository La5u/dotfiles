#!/usr/bin/env bash
set -euo pipefail

# Find the USB webcam (video interface class 0e). Its interfaces vanish while it is
# deauthorized, so remember the device path to be able to turn it back on.
CACHE="${XDG_RUNTIME_DIR:-/tmp}/webcam-usb-device"
DEV=""
for class in /sys/bus/usb/devices/*:*/bInterfaceClass; do
    if [[ -r $class && $(<"$class") == 0e ]]; then
        iface=${class%/*}
        DEV="${iface%%:*}/authorized"
        printf '%s\n' "$DEV" >"$CACHE"
        break
    fi
done
[[ -z $DEV && -r $CACHE ]] && DEV=$(<"$CACHE")

# No USB webcam (built-in cameras on some laptops are not USB): hide the module.
if [[ -z $DEV || ! -r $DEV ]]; then
    printf '{"text":""}\n'
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
    printf '{"text":"󰖠","alt":"on","class":"on","tooltip":"Webcam: on (click to disable)"}\n'
else
    printf '{"text":"󱜷","alt":"off","class":"off","tooltip":"Webcam: off (click to enable)"}\n'
fi
