#!/usr/bin/env bash
# Turn the display off (not suspend): agents, downloads and audio keep running.
# Any mouse movement or key press turns it back on (misc:*_enables_dpms).
# The delay stops the click itself from waking the screen.
sleep 1
hyprctl dispatch 'hl.dsp.dpms({action = "off"})' >/dev/null
