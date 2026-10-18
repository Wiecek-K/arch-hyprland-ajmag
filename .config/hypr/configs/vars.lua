-- Programy używane w bindach i autostarcie (dawne $terminal, $fileManager, $menu, $mainMod).
return {
    mainMod     = "SUPER",
    terminal    = "kitty",
    fileManager = "nautilus",
    menu        = "qs -c ajmashell ipc call launcher toggle", -- launcher Ajmashella
    -- Ajmashell działa jako usługa systemd użytkownika (~/.config/systemd/user/ajmashell.service, ticket 23)
    shellService = "ajmashell.service",
    scripts     = "~/.config/hypr/scripts",
}
