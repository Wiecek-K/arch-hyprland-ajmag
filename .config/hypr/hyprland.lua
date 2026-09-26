-- Hyprland — punkt wejścia (Lua, od 0.56). Zastępuje hyprland.conf.
--
-- Moduły w configs/ ładowane przez require (safe-require: błąd w jednym module nie zabija reszty).
-- Kolejność ma znaczenie:
--   env        — zmienne środowiskowe, jak najwcześniej (GPU: AQ_DRM_DEVICES)
--   keybinds   — zaraz potem: błąd w dalszym module nie odbierze klawiatury (emergency mode tylko przy 0 bindów)
--   monitors   — generowany przez nwg-displays (pcall: brak pliku nie może zabić configu)
--   looknfeel  — wygląd + kolory z colors.lua (generowany przez matugen)
--
-- Walidacja przed zapisem: Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
-- Autoreload śledzi ten plik i wszystko ładowane przez require (także colors.lua, monitors.lua).

require("configs.env")
require("configs.keybinds")

local ok, err = pcall(require, "monitors")
if not ok then
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
    print("monitors.lua: " .. tostring(err))
end

require("configs.looknfeel")
require("configs.animations")
require("configs.input")
require("configs.rules")
require("configs.autostart")
