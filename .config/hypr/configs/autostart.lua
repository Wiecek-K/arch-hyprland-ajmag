-- Autostart (dawne exec-once). Odpala się raz przy starcie sesji — nie przy reloadzie ani --verify-config.
local v = require("configs.vars")

hl.on("hyprland.start", function()
    hl.exec_cmd("nm-applet")
    hl.exec_cmd(v.scripts .. "/shellset.sh start " .. v.shell) -- zestaw shella: vars.lua → shell
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("udiskie --tray")
end)
