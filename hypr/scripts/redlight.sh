#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
mkdir -p "$state_dir"
read_temperature() {
    local value
    value=$(hyprctl hyprsunset temperature 2>/dev/null) || return 1
    [[ $value =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$value"
}

if [[ ${1:-status} == status ]]; then
    if ! temp=$(read_temperature); then
        printf '󱓤\n'
    elif (( temp < 6500 )); then
        printf ' %sK\n' "$temp"
    else
        printf '󱓤\n'
    fi
    exit 0
fi

if [[ ${1:-} == menu ]]; then
    choice=$(printf 'Toggle night light\nWarmer\nCooler\nReset temperature\n' | rofi -dmenu -p 'Night light') || exit 0
    case "$choice" in
        'Toggle night light') exec "$0" toggle ;;
        'Warmer') exec "$0" up ;;
        'Cooler') exec "$0" down ;;
        'Reset temperature') exec "$0" reset ;;
        *) exit 0 ;;
    esac
fi

# Serialize clicks/scrolls so updates cannot race each other.
exec 9>"${XDG_RUNTIME_DIR:-$state_dir}/waybar-redlight.lock"
flock 9
if ! temp=$(read_temperature); then
    if ! pgrep -x hyprsunset >/dev/null; then
        nohup hyprsunset -t 6500 </dev/null >"$state_dir/hyprsunset.log" 2>&1 9>&- &
    fi
    for ((i=0; i<30; i++)); do
        if temp=$(read_temperature); then break; fi
        sleep 0.1
    done
    temp=$(read_temperature) || exit 1
fi

warm=4000
if [[ -r $state_dir/night-temperature ]]; then
    read -r saved < "$state_dir/night-temperature" || true
    if [[ ${saved:-} =~ ^[0-9]{4}$ ]] && (( saved >= 2000 && saved < 6500 )); then
        warm=$saved
    fi
fi
case "${1:-}" in
    toggle)
        if (( temp < 6500 )); then
            printf '%s\n' "$temp" > "$state_dir/night-temperature"
            target=6500
        else
            target=$warm
        fi
        ;;
    up)
        target=$((temp - 200))
        (( target >= 2000 )) || target=2000
        ;;
    down)
        target=$((temp + 200))
        (( target <= 6500 )) || target=6500
        ;;
    reset) target=6500 ;;
    *) exit 2 ;;
esac
if (( target < 6500 )); then
    hyprctl hyprsunset temperature "$target" >/dev/null
    printf '%s\n' "$target" > "$state_dir/night-temperature"
else
    # Night light off: restore neutral colors and stop hyprsunset instead of idling at 6500K.
    hyprctl hyprsunset identity >/dev/null 2>&1 || true
    pkill -x hyprsunset || true
fi
pkill -RTMIN+8 -x waybar || true
