#!/usr/bin/env bash
set -euo pipefail

# Gaming mode: turn Wi-Fi power saving off for lower latency (e.g. Minecraft).
# The toggle also rewrites NetworkManager's wifi.powersave default (2 = off, 3 = on),
# so reconnects and reboots keep the chosen state and the icon stays accurate.
NM_CONF=/etc/NetworkManager/conf.d/wifi-powersave.conf
IFACE=$(iw dev | awk '/Interface/{print $2; exit}')

if [[ -z "$IFACE" ]]; then
    printf '{"text":"","alt":"unavailable","class":"off","tooltip":"Wi-Fi unavailable"}\n'
    exit 0
fi

ps=$(iw dev "$IFACE" get power_save | awk '{print $3}')
if [[ "${1:---status}" == "--toggle" ]]; then
    target=off
    [[ "$ps" == "off" ]] && target=on
    if ! sudo -n iw dev "$IFACE" set power_save "$target"; then
        notify-send --urgency=normal "Wi-Fi" "Could not change Wi-Fi power saving." || true
    else
        nm=3
        [[ "$target" == "off" ]] && nm=2
        if ! printf '[connection]\nwifi.powersave = %s\n' "$nm" | sudo -n tee "$NM_CONF" >/dev/null \
            || ! sudo -n nmcli general reload conf; then
            notify-send --urgency=normal "Wi-Fi" "Power saving changed, but it will not survive a reconnect." || true
        fi
    fi
    ps=$(iw dev "$IFACE" get power_save | awk '{print $3}')
fi

if [[ "$ps" == "off" ]]; then
    printf '{"text":"","alt":"on","class":"on","tooltip":"Gaming mode: on, Wi-Fi power saving off (click to save power)"}\n'
else
    printf '{"text":"","alt":"off","class":"off","tooltip":"Gaming mode: off, Wi-Fi power saving on (click for low latency)"}\n'
fi
