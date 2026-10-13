-- Programy używane w bindach i autostarcie (dawne $terminal, $fileManager, $menu, $mainMod).
return {
    mainMod     = "SUPER",
    terminal    = "kitty",
    fileManager = "nautilus",
    menu        = "~/.config/hypr/scripts/launcher.sh", -- Ajmashell launcher, rofi under the Waybar set
    menuFallback = "rofi -show drun",
    -- Zestaw shella startowany po zalogowaniu: "waybar" (Waybar + swaync) albo "ajmashell" (Ajmashell, Quickshell).
    -- Jedyne miejsce zmiany domyślnego zestawu. Przełączanie w trakcie sesji: SUPER+SHIFT+R (scripts/shellset.sh).
    shell       = "ajmashell",
    scripts     = "~/.config/hypr/scripts",
}
