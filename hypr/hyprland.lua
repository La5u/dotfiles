-- Every monitor at its native resolution and automatic scale, placed left to right.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- True when a battery is discharging; desktops and plugged-in laptops count as AC.
local function on_battery()
    local p = io.popen("grep -sqx Discharging /sys/class/power_supply/*/status && echo yes")
    local r = p:read("l")
    p:close()
    return r == "yes"
end

-- Laptop panels run at the mode closest to 60 Hz on battery and at their fastest
-- mode on AC, always at native resolution. External monitors keep their default.
-- Also called by bin/refresh-on-power when the charger is plugged or unplugged.
function set_refresh_rate()
    local battery = on_battery()
    for _, m in ipairs(hl.get_monitors()) do
        if m.name:match("^eDP") or m.name:match("^LVDS") or m.name:match("^DSI") then
            local native
            for _, mode in ipairs(m.available_modes) do
                if mode.preferred then native = mode end
            end
            local best
            for _, mode in ipairs(m.available_modes) do
                if native and mode.width == native.width and mode.height == native.height then
                    local better = not best
                        or (battery and math.abs(mode.refresh_rate - 60) < math.abs(best.refresh_rate - 60))
                        or (not battery and mode.refresh_rate > best.refresh_rate)
                    if better then best = mode end
                end
            end
            if best and math.abs(best.refresh_rate - m.refresh_rate) > 0.5 then
                hl.monitor({
                    output = m.name,
                    mode = string.format("%dx%d@%.3f", best.width, best.height, best.refresh_rate),
                    position = "auto",
                    -- Keep the current scale, which local.lua may have set.
                    scale = m.scale,
                })
            end
        end
    end
end
hl.on("monitor.added", set_refresh_rate)
hl.on("config.reloaded", set_refresh_rate)

-- Per-machine tweaks (extra monitors, mice, one-off binds) go in local.lua,
-- which is not part of the dotfiles.
local local_config = os.getenv("HOME") .. "/.config/hypr/local.lua"
local fh = io.open(local_config)
if fh then
    fh:close()
    dofile(local_config)
end

local terminal = "ghostty"
local file_manager = "thunar"
local menu = "rofi -show drun"
local main_mod = "SUPER"

-- Raw-axis 3x3 workspace gestures (1-3 / 4-6 / 7-9).
hl.plugin.load(os.getenv("HOME") .. "/.local/share/hypr/gridgestures.so")

hl.on("hyprland.start", function()
    set_refresh_rate()
    -- Start in the center of the 3x3 workspace grid.
    hl.exec_cmd("hyprctl dispatch 'hl.dsp.focus({ workspace = 5 })'")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    -- Password prompts for apps that need admin rights (mounting drives, etc.).
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("firefox")
    hl.exec_cmd("waypaper --restore")
    -- hyprsunset is started on demand by scripts/redlight.sh
    hl.exec_cmd("waybar")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("refresh-on-power")
end)

hl.env("XCURSOR_SIZE", "20")
hl.env("HYPRCURSOR_SIZE", "20")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_SCALE_FACTOR", "1")

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
    general = {
        border_size = 0,
        gaps_in = 0,
        gaps_out = 0,
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        blur = {
            enabled = false,
        },
        shadow = {
            enabled = false,
        },
    },
    animations = {
        enabled = false,
    },
    render = {
        -- Fullscreen apps (video, games) bypass compositing.
        direct_scanout = 2,
    },
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        -- Wake the screen after the Waybar screen-off button.
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
    },
    input = {
        kb_layout = "us,fr,ru",
        kb_options = "grp:alt_shift_toggle",
        follow_mouse = 1,
        mouse_refocus = false,
        accel_profile = "flat",
        sensitivity = 1,
        touchpad = {
            natural_scroll = true,
            disable_while_typing = false,
        },
    },
})

-- Three-finger 3x3 navigation is provided by the Hyprgrid plugin.

hl.bind("SUPER + CTRL + SHIFT + R", hl.dsp.exec_cmd("reboot"))
hl.bind("SUPER + CTRL + SHIFT + S", hl.dsp.exec_cmd("shutdown now"))
hl.bind("SUPER + S", hl.dsp.exec_cmd("hyprshot -m region"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("frozen-shot"))
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("wl-paste | swappy -f -"))
hl.bind("SUPER + F", hl.dsp.window.fullscreen())

hl.bind("SUPER + W", hl.dsp.exec_cmd("bash ~/.config/waybar/toggle-bar.sh"))
hl.bind("SUPER + SHIFT + F", hl.dsp.exec_cmd("firefox"))
hl.bind("SUPER + SHIFT + Q", hl.dsp.exec_cmd("qbittorrent"))
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("waypaper"))
hl.bind("SUPER + SHIFT + Z", hl.dsp.exec_cmd("zed"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("chromium --password-store=basic"))

hl.bind(main_mod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(main_mod .. " + C", hl.dsp.window.close())
hl.bind(main_mod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(main_mod .. " + E", hl.dsp.exec_cmd(file_manager))
hl.bind(main_mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(main_mod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(main_mod .. " + P", hl.dsp.window.pseudo())
hl.bind(main_mod .. " + J", hl.dsp.layout("togglesplit"))

hl.bind(main_mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(main_mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(main_mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(main_mod .. " + down", hl.dsp.focus({ direction = "down" }))

for workspace = 1, 9 do
    local key = workspace
    hl.bind(main_mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(main_mod .. " + X", hl.dsp.workspace.toggle_special("magic"))
hl.bind(main_mod .. " + SHIFT + X", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    match = { class = "thunar" },
    float = true,
    size = "800 500",
})

hl.window_rule({
    match = {
        class = "(waypaper|nm-connection-editor|imv|org\\.pulseaudio\\.pavucontrol|.*setting.*)",
    },
    float = true,
})

hl.window_rule({
    -- Never dim or blank the screen while something is fullscreen (movies, games).
    name = "idle-inhibit-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})
hl.window_rule({
    match = { float = true },
    center = true,
})
