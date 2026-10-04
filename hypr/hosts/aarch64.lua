-- Apple Silicon MacBook (Fedora Asahi Remix).
-- Native resolution at automatic scale; check names with `hyprctl monitors`.
hl.monitor({
    output = "eDP-1",
    mode = "preferred",
    position = "0x0",
    scale = "auto",
})

-- Start in the center of the 3x3 workspace grid.
hl.workspace_rule({ workspace = "5", monitor = "eDP-1", default = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
