-- Reguły okien i warstw. Tagi najpierw — reguły niżej dopasowują się po tagach.

-- === TAGI ===
hl.window_rule({ name = "tag-multimedia-video", match = { class = "^([Mm]pv|vlc)$" }, tag = "+multimedia_video" })
hl.window_rule({ name = "tag-settings-1", match = { class = "^(nm-applet|nm-connection-editor|blueman-manager|org.gnome.FileRoller)$" }, tag = "+settings" })
hl.window_rule({ name = "tag-settings-2", match = { class = "^(org.gnome.DiskUtility|wihotspot(-gui)?)$" }, tag = "+settings" })
hl.window_rule({ name = "tag-viewer-1", match = { class = "^(org.gnome.SystemMonitor)$" }, tag = "+viewer" })
hl.window_rule({ name = "tag-viewer-2", match = { class = "^(org.gnome.Evince)$" }, tag = "+viewer" })
hl.window_rule({ name = "tag-viewer-3", match = { class = "^(eog|org.gnome.Loupe)$" }, tag = "+viewer" })

-- === APLIKACJE: BLUR I PRZEZROCZYSTOŚĆ ===
hl.window_rule({ name = "rofi-animation", match = { class = "^(rofi)$" }, animation = "popin 80%" })
hl.window_rule({ name = "steam-tiling", match = { initial_class = "^(steam)$" }, tile = true })

hl.window_rule({
    name    = "windowrule-1",
    match   = { tag = "multimedia_video*" },
    no_blur = true,
    opacity = "1.0 override 1.0 override",
    float   = true,
    size    = { 900, 506 },
})
hl.window_rule({ name = "windowrule-2", match = { tag = "settings*" }, opacity = "0.8 override 0.8 override", float = true })
hl.window_rule({ name = "windowrule-3", match = { class = "^(org.gnome.Nautilus)$" }, opacity = "0.8 override 0.8 override" })
hl.window_rule({ name = "windowrule-4", match = { class = "^(org.gnome.TextEditor|mousepad)$" }, opacity = "0.9 override 0.9 override" })
hl.window_rule({
    name    = "windowrule-5",
    match   = { class = "^(org.pulseaudio.pavucontrol)$" },
    opacity = "0.9 override 0.9 override",
    float   = true,
    size    = "(monitor_w*0.5) (monitor_h*0.6)",
})
hl.window_rule({ name = "satty-float", match = { class = ".*satty.*" }, float = true })

-- Kitty: aktywne 0.85 | nieaktywne 0.7 | fullscreen 1.0
hl.window_rule({ name = "windowrule-6", match = { class = "^(kitty)$" }, opacity = "0.85 override 0.7 override 1.0 override" })
-- Spotify
hl.window_rule({ name = "windowrule-7", match = { class = "^(spotify)$" }, opacity = "0.91 override 0.8 override 1.0 override" })

-- === WYSOKA WIDOCZNOŚĆ ===
-- Przeglądarki
hl.window_rule({
    name    = "windowrule-8",
    match   = { class = "^(firefox|org.mozilla.firefox|[Cc]hromium|[Gg]oogle-chrome|brave-browser|zen)$" },
    opacity = "1.0 override 0.95 override 1.0 override",
})
-- Edytory kodu
hl.window_rule({
    name    = "windowrule-9",
    match   = { class = "^(code-oss|vscode|code|jetbrains-.*|Alacritty|gedit)$" },
    opacity = "1.0 override 1.0 override 1.0 override",
})
-- Komunikatory
hl.window_rule({
    name    = "windowrule-10",
    match   = { class = "^(vesktop|discord|org.telegram.desktop|Slack)$" },
    opacity = "1.0 override 0.95 override 1.0 override",
})
-- Notatki
hl.window_rule({
    name    = "windowrule-11",
    match   = { class = "^(obsidian|Logseq)$" },
    opacity = "0.98 override 0.94 override 1.0 override",
})

-- === WARSTWY ===
hl.layer_rule({ name = "layerrule-1", match = { namespace = "waybar" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ name = "layerrule-2", match = { namespace = "swaync-control-center" }, blur = true, ignore_alpha = 0.5, xray = false, no_anim = true })
hl.layer_rule({ name = "layerrule-3", match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.5, xray = false })
hl.layer_rule({ name = "layerrule-4", match = { namespace = "wlogout" }, blur = true, ignore_alpha = 0 })
hl.layer_rule({ name = "layerrule-5", match = { namespace = "flameshot" }, blur = true, ignore_alpha = 0 })

-- === PŁYWAJĄCE I ROZMIARY ===
hl.window_rule({ name = "windowrule-12", match = { tag = "viewer*" }, float = true })

-- Ignoruj żądania maksymalizacji (poza Steamem i grami)
hl.window_rule({
    name           = "windowrule-13",
    match          = { class = "negative:^(steam_app_|steam|WaylandToX11).*$" },
    suppress_event = "maximize",
})

-- Problemy z przeciąganiem w XWayland
hl.window_rule({
    name     = "windowrule-14",
    match    = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Okna dialogowe
hl.window_rule({
    name   = "windowrule-15",
    match  = { title = "^(Save As|Save a File|Pick Files)$" },
    float  = true,
    size   = "(monitor_w*0.5) (monitor_h*0.6)",
    center = true,
})
hl.window_rule({
    name  = "windowrule-16",
    match = { initial_title = "^(Open Files)$" },
    float = true,
    size  = "(monitor_w*0.7) (monitor_h*0.6)",
})
hl.window_rule({ name = "windowrule-17", match = { class = ".*" }, suppress_event = "activate" })
