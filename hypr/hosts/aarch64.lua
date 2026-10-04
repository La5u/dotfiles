-- Apple Silicon MacBook (Fedora Asahi Remix).
-- Native resolution at automatic scale; check names with `hyprctl monitors`.
-- 60 Hz on battery, 120 Hz on AC. Runs on every config load, and
-- bin/refresh-on-power calls it when the charger is plugged or unplugged.
function set_refresh_rate()
    local ac = io.open("/sys/class/power_supply/macsmc-ac/online")
    local online = ac and ac:read("l") == "1"
    if ac then ac:close() end
    hl.monitor({
        output = "eDP-1",
        mode = online and "3024x1890@120" or "3024x1890@60",
        position = "0x0",
        scale = "auto",
    })
end
set_refresh_rate()

-- Start in the center of the 3x3 workspace grid.
hl.workspace_rule({ workspace = "5", monitor = "eDP-1", default = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
