-- Autostart (dawne exec-once). Odpala się raz przy starcie sesji — nie przy reloadzie ani --verify-config.
local v = require("configs.vars")

-- Zmienne z env.lua, których potrzebuje Ajmashell (Qt, kursor) i programy, które uruchamia. Sesja startuje przez
-- uwsm: menedżer systemd użytkownika ich nie zna, a Ajmashell jest usługą systemd (restart po awarii, ticket 23).
local shellEnv = "QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_AUTO_SCREEN_SCALE_FACTOR QT_WAYLAND_DISABLE_WINDOWDECORATION "
    .. "GDK_BACKEND XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE"

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user import-environment " .. shellEnv .. " && systemctl --user start " .. v.shellService)
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("udiskie") -- bez --tray: montowanie i powiadomienia bez ikony (ticket 23)
end)
