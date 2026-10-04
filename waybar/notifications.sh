#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == toggle ]]; then
    dunstctl set-paused toggle
fi

if ! paused=$(dunstctl is-paused 2>/dev/null); then
    printf '%s\n' '{"text":"󰂛","class":"unavailable","tooltip":"Dunst unavailable"}'
    exit 0
fi
waiting=$(dunstctl count waiting)
if [[ $paused == true ]]; then
    printf '{"text":"󰂛 %s","class":"paused","tooltip":"Notifications paused · %s queued; click to resume and show queued notifications"}\n' "$waiting" "$waiting"
else
    printf '%s\n' '{"text":"󰂚","class":"enabled","tooltip":"Notifications enabled · click to pause and queue"}'
fi
