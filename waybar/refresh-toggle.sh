#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == --toggle ]]; then
    hyprctl eval 'toggle_refresh_rate()' >/dev/null
fi

hyprctl monitors -j | jq -c '
    [.[] | select(.name | test("^(eDP|LVDS|DSI)"))][0] as $panel
    | if $panel == null then
        {text: "", tooltip: "No built-in display"}
      else
        ($panel.refreshRate | round) as $rate
        | {text: (($rate | tostring) + "Hz"),
           class: (if $rate > 90 then "fast" else "normal" end),
           tooltip: ("Display: " + ($rate | tostring) + " Hz — click to switch to "
                     + (if $rate > 90 then "60" else "120" end) + " Hz")}
      end'
