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

# Built-in platform camera (Apple Silicon ISP under Asahi): toggle it by
# unbinding/binding the driver instead of USB authorization.
PLATFORM_DRIVER=/sys/bus/platform/drivers/apple-isp
PLATFORM_DEV=""
if [[ -z $DEV && -d $PLATFORM_DRIVER ]]; then
    PLATFORM_DEV=$(basename /sys/bus/platform/devices/*.isp 2>/dev/null || true)
    [[ -e /sys/bus/platform/devices/$PLATFORM_DEV ]] || PLATFORM_DEV=""
fi

# No webcam found: hide the module.
if [[ -z $PLATFORM_DEV ]] && [[ -z $DEV || ! -r $DEV ]]; then
    printf '{"text":""}\n'
    exit 0
fi

get_state() {
    if [[ -n $PLATFORM_DEV ]]; then
        [[ -e $PLATFORM_DRIVER/$PLATFORM_DEV ]] && echo 1 || echo 0
    else
        cat "$DEV"
    fi
}

state=$(get_state)
# --off is run at session start: the kernel rebinds the camera on every boot.
if [[ "${1:---status}" == "--toggle" || ( "${1:-}" == "--off" && "$state" == "1" ) ]]; then
    if [[ -n $PLATFORM_DEV ]]; then
        target=bind
        [[ "$state" == "1" ]] && target=unbind
        ok=0; printf '%s\n' "$PLATFORM_DEV" | sudo -n tee "$PLATFORM_DRIVER/$target" >/dev/null || ok=1
    else
        target=1
        [[ "$state" == "1" ]] && target=0
        ok=0; printf '%s\n' "$target" | sudo -n tee "$DEV" >/dev/null || ok=1
    fi
    if (( ok != 0 )); then
        notify-send --urgency=normal "Webcam" "Could not change webcam power." || true
    fi
    state=$(get_state)
fi

if [[ "$state" == "1" ]]; then
    printf '{"text":"󰄀","alt":"on","class":"on","tooltip":"Webcam: on (click to disable)"}\n'
else
    printf '{"text":"󰗟","alt":"off","class":"off","tooltip":"Webcam: off (click to enable)"}\n'
fi
