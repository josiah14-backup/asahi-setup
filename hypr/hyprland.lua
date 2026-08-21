-- Hyprland config mapped from pop-os-setup/.xmonad/xmonad.hs.
-- Lua replaces the deprecated hyprland.conf format removed in Hyprland 0.57.

hl.monitor({ output = "eDP-1", mode = "3456x2160@120", position = "0x0", scale = 1.5 })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "-1920x0", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("dbus-update-activation-environment --systemd --all && systemctl --user start graphical-session.target")
    hl.exec_cmd("systemctl --user start plasma-powerdevil.service plasma-kscreen.service")
    hl.exec_cmd("hypridle")
end)

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "dvorak",
        kb_options = "caps:swapescape,ctrl:ralt_rctrl",
        follow_mouse = 1,
    },
    general = {
        layout = "master",
        gaps_in = 3,
        gaps_out = 7,
        border_size = 2,
        col = {
            active_border = "rgba(cb4b16ff)",
            inactive_border = "rgba(586e75aa)",
        },
    },
    dwindle = {
        default_split_ratio = 1.6,
        force_split = 2,
        preserve_split = true,
    },
})

local function bind(keys, dispatcher, options)
    options = options or {}
    options.description = keys
    hl.bind(keys, dispatcher, options)
end

-- Window, layout, and application bindings.
bind("SUPER + SHIFT + Q", hl.dsp.exit())
bind("SUPER + Return", hl.dsp.exec_cmd("foot tmux attach"))

bind("SUPER + H", hl.dsp.focus({ direction = "left" }))
bind("SUPER + J", hl.dsp.focus({ direction = "down" }))
bind("SUPER + K", hl.dsp.focus({ direction = "up" }))
bind("SUPER + L", hl.dsp.focus({ direction = "right" }))
bind("SUPER + S", hl.dsp.focus({ direction = "right" }))

bind("SUPER + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
bind("SUPER + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
bind("SUPER + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
bind("SUPER + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
bind("SUPER + SHIFT + S", hl.dsp.window.move({ direction = "right" }))

bind("SUPER + U", hl.dsp.layout("mfact +0.05"))
bind("SUPER + D", hl.dsp.layout("mfact -0.05"))
bind("SUPER + comma", hl.dsp.layout("removemaster"))
bind("SUPER + period", hl.dsp.layout("addmaster"))
bind("SUPER + SHIFT + comma", hl.dsp.layout("swapnext"))
bind("SUPER + SHIFT + period", hl.dsp.layout("swapprev"))
bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }))
bind("SUPER + 0", hl.dsp.window.fullscreen())

bind("SUPER + apostrophe", hl.dsp.focus({ monitor = "-1" }))
bind("SUPER + P", hl.dsp.focus({ monitor = "+1" }))
bind("SUPER + C", hl.dsp.window.resize({ x = -40, y = -40, relative = true }))
bind("SUPER + R", hl.dsp.window.resize({ x = 40, y = 40, relative = true }))
bind("SUPER + SHIFT + apostrophe", hl.dsp.window.move({ monitor = "-1" }))
bind("SUPER + SHIFT + P", hl.dsp.window.move({ monitor = "+1" }))

bind("SUPER + F", hl.dsp.exec_cmd("dolphin"))
bind("SUPER + E", hl.dsp.exec_cmd("foot nvim"))
bind("SUPER + W", hl.dsp.exec_cmd("gtk-launch $(xdg-settings get default-web-browser)"))
bind("SUPER + escape", hl.dsp.exec_cmd("hyprlock"))
bind("SUPER + SHIFT + escape", hl.dsp.exec_cmd("systemctl suspend"))
bind("SUPER + X", hl.dsp.window.close())
bind("SUPER + M", hl.dsp.layout("swapwithmaster"))
bind("SUPER + grave", hl.dsp.exec_cmd("~/.config/hypr/scripts/keybind-cheatsheet.sh"))
bind("SUPER + space", hl.dsp.exec_cmd("fuzzel"))

bind("SUPER + SHIFT + Return", hl.dsp.exec_cmd("~/.config/hypr/scripts/set-layout.sh"))
for i, layout in ipairs({ "left", "top", "right", "bottom", "center", "dwindle" }) do
    bind("SUPER + CTRL + " .. i, hl.dsp.exec_cmd("~/.config/hypr/scripts/set-layout.sh " .. layout))
end

for i = 1, 9 do
    bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
    bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Media keys remain available while locked.
local locked = { locked = true }
bind("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute 0 toggle"), locked)
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("amixer -q sset Master 3%-"), locked)
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("amixer -q sset Master 3%+"), locked)
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +10%"), locked)
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), locked)

-- Window grouping/tabbing.
bind("SUPER + CTRL + H", hl.dsp.window.move({ into_group = "left" }))
bind("SUPER + CTRL + S", hl.dsp.window.move({ into_group = "right" }))
bind("SUPER + CTRL + L", hl.dsp.window.move({ into_group = "right" }))
bind("SUPER + CTRL + J", hl.dsp.window.move({ into_group = "down" }))
bind("SUPER + CTRL + K", hl.dsp.window.move({ into_group = "up" }))
bind("SUPER + G", hl.dsp.group.toggle())
bind("SUPER + SHIFT + G", hl.dsp.window.move({ out_of_group = true }))
bind("SUPER + Tab", hl.dsp.group.next())
bind("SUPER + SHIFT + Tab", hl.dsp.group.prev())

bind("SUPER + B", hl.dsp.exec_cmd("killall -SIGUSR1 waybar"))
