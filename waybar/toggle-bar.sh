#!/usr/bin/env bash
# Refresh signal-driven status modules on demand, then toggle visibility.
pkill -RTMIN+8 -x waybar || exit 0
pkill -USR1 -x waybar
