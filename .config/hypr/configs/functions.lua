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

return M
