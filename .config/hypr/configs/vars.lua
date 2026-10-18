-- Programy używane w bindach i autostarcie (dawne $terminal, $fileManager, $menu, $mainMod).
-- Wywołanie IPC Ajmashella: v.ipc .. "launcher toggle" (cele: `qs -c ajmashell ipc show`).
local ipc = "qs -c ajmashell ipc call "

return {
    mainMod      = "SUPER",
    terminal     = "kitty",
    fileManager  = "nautilus",
    ipc          = ipc,
    menu         = ipc .. "launcher toggle", -- launcher Ajmashella
    -- Ajmashell działa jako usługa systemd użytkownika (~/.config/systemd/user/ajmashell.service, ticket 23)
    shellService = "ajmashell.service",
    scripts      = "~/.config/hypr/scripts",
}
