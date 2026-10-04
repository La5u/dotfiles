#!/bin/sh

MON="eDP-1"

if [ "$(cat /sys/class/power_supply/ACAD/online)" = "1" ]; then
  hyprctl keyword monitor "$MON,preferred,auto,1.25"
else
  hyprctl keyword monitor "$MON,1920x1080@60,auto,1.25"
fi

