-- Arch laptop (AMD, 1920x1080 panel).
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60",
    position = "0x0",
    scale = 1.25,
})

-- Ignore the phantom 640x480 HDMI output so it cannot steal workspace 1.
hl.monitor({
    output = "HDMI-A-1",
    disabled = true,
})

-- Start in the center of the 3x3 workspace grid.
hl.workspace_rule({ workspace = "5", monitor = "eDP-1", default = true })

hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})

hl.bind("SUPER + H", hl.dsp.exec_cmd("hypr-refresh.sh"))
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd('imv "/mnt/win/Users/Lasu/timetable.png"'))
hl.bind("CTRL + ALT + P", hl.dsp.exec_cmd('imv "/mnt/win/Users/Lasu/periodic table.svg"'))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto org.freedesktop.login1.Session SetBrightness ssu backlight amdgpu_bl1 $(( $(brightnessctl -d amdgpu_bl1 get) + 6554 > 65535 ? 65535 : $(brightnessctl -d amdgpu_bl1 get) + 6554 ))"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto org.freedesktop.login1.Session SetBrightness ssu backlight amdgpu_bl1 $(( $(brightnessctl -d amdgpu_bl1 get) - 6554 < 1311 ? 1311 : $(brightnessctl -d amdgpu_bl1 get) - 6554 ))"), { locked = true, repeating = true })
