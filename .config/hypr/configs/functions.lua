-- Logika wołana z bindów i z zewnątrz (hyprctl eval). Zastępuje skrypty oparte o `hyprctl keyword`
-- (wyłączone pod Lua): gamemode.sh.
-- Bez blokujących os.execute/io.popen — bind ma watchdog 100 ms.

local M = {}

local function notify(title, body)
    hl.exec_cmd(string.format("notify-send -u low -t 2000 %q %q", title, body))
end

-- SUPER+F1: wyłącza efekty (animacje, blur, cienie, zaokrąglenia, odstępy); drugie wciśnięcie przywraca config.
function M.gamemode()
    if hl.get_config("animations.enabled") then
        hl.config({
            animations = { enabled = false },
            decoration = { shadow = { enabled = false }, blur = { enabled = false }, rounding = 0 },
            general    = { gaps_in = 0, gaps_out = 0, border_size = 1 },
        })
        notify("Gamemode", "Enabled (Max Performance)")
    else
        -- reload odtwarza wartości z configu (brak hl.dsp.reload_config w 0.56.2)
        hl.exec_cmd("hyprctl reload")
        notify("Gamemode", "Disabled (Visuals Restored)")
    end
end

-- Ajmashell, wygląd „fancy2” (ticket 13): reguły, które zdejmują blur spod launchera, popupów Baru (Orbita, popup audio)
-- i Centrum sterowania (ticket 14). Tworzy je rules.lua w swoim miejscu (po layerrule-6/7/8: późniejsza reguła nadpisuje te same pola), wyłączone.
-- Lista zostaje w tym module; z zewnątrz tylko ajmashellBlurOff.
local blurOffRules = {}

function M.ajmashellBlurOffRules()
    blurOffRules = {
        hl.layer_rule({ name = "ajmashell-opaque-launcher", match = { namespace = "ajmashell-launcher" }, blur = false }),
        hl.layer_rule({ name = "ajmashell-opaque-popups", match = { namespace = "ajmashell-bar" }, blur_popups = false }),
        hl.layer_rule({ name = "ajmashell-opaque-control", match = { namespace = "ajmashell-control" }, blur = false }),
    }
    M.ajmashellBlurOff(false)
end

-- true: bez bluru pod launcherem, Orbitą i Centrum sterowania. Woła shell (singletons/look/BlurOff.qml) przy zmianie wyglądu,
-- przy starcie i po przeładowaniu configu (przeładowanie tworzy reguły od nowa, wyłączone).
function M.ajmashellBlurOff(on)
    for _, rule in ipairs(blurOffRules) do
        rule:set_enabled(on)
    end
end

return M
