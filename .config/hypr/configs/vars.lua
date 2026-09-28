-- Programy używane w bindach i autostarcie (dawne $terminal, $fileManager, $menu, $mainMod).
return {
    mainMod     = "SUPER",
    terminal    = "kitty",
    fileManager = "nautilus",
    menu        = "rofi -show drun",
    -- Zestaw shella startowany po zalogowaniu: "waybar" (Waybar + swaync) albo "ajmashell" (Quickshell).
    -- Jedyne miejsce zmiany domyślnego zestawu. Przełączanie w trakcie sesji: SUPER+SHIFT+R (scripts/shellset.sh).
    shell       = "waybar",
    scripts     = "~/.config/hypr/scripts",
}
