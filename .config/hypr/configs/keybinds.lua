-- Skróty klawiszowe. Ładowane zaraz po env — błąd w innym module nie odbierze klawiatury.
-- Format: "MOD + MOD + klawisz". Tylko SHIFT/CTRL/ALT/SUPER (LSHIFT = błąd w Lua).

local v = require("configs.vars")
local fn = require("configs.functions")
local dsp = hl.dsp
local M = v.mainMod

-- Każdy skrót ma opis — czyta go podgląd skrótów w shellu (`hyprctl binds -j`).
local function bind(keys, description, action, opts)
    local o = { description = description }
    for k, val in pairs(opts or {}) do
        o[k] = val
    end
    hl.bind(keys, action, o)
end

local function exec(cmd, rules)
    return dsp.exec_cmd(cmd, rules)
end

-- === APLIKACJE I SESJA ===
bind(M .. " + Return", "Terminal", exec(v.terminal))
bind(M .. " + SHIFT + Return", "Terminal pływający", exec(v.terminal, { float = true, size = { 800, 550 } }))
bind(M .. " + Q", "Zamknij okno", dsp.window.close())
bind("CTRL + ALT + Delete", "Wyjdź z Hyprlanda", dsp.exit())
bind(M .. " + E", "Menedżer plików", exec(v.fileManager))
bind(M .. " + Space", "Przełącz pływanie okna", dsp.window.float())
bind(M .. " + D", "Launcher aplikacji", exec(v.menu))
bind(M .. " + O", "Tryb pseudo okna", dsp.window.pseudo()) -- dwindle
bind(M .. " + J", "Zmień kierunek podziału", dsp.layout("togglesplit"))
bind(M .. " + R", "Restart Waybara", exec(v.scripts .. "/wbrestart.sh"))
bind(M .. " + B", "Przeglądarka", exec('xdg-open "https://"')) -- domyślna przeglądarka
bind(M .. " + L", "Menu zasilania", exec(v.scripts .. "/Wlogout.sh"))
bind(M .. " + SHIFT + F", "Pełny ekran", dsp.window.fullscreen())
bind(M .. " + CTRL + S", "Zrzut ekranu", exec(v.scripts .. "/screenshot.sh"))
bind(M .. " + W", "Zmień tapetę", exec(v.scripts .. "/wppicker.sh"))
bind(M .. " + SHIFT + Q", "Zabij proces aktywnego okna", exec(v.scripts .. "/KillActiveProcess.sh"))
bind(M .. " + C", "Próbnik koloru", exec("hyprpicker -a"))
bind(M .. " + CTRL + B", "Styl Waybara", exec(v.scripts .. "/WaybarStyles.sh"))
bind(M .. " + ALT + B", "Układ Waybara", exec(v.scripts .. "/WaybarLayout.sh"))
bind(M .. " + H", "Ukryj/pokaż Waybar", exec("pkill -SIGUSR1 waybar")) -- ukryj Waybar
bind(M .. " + SHIFT + E", "Yazi w terminalu", exec("kitty yazi"))
bind(M .. " + F1", "Tryb gry (efekty wizualne)", fn.gamemode) -- gamemode: przełącza efekty wizualne

-- === FOKUS, PRZENOSZENIE, ROZMIAR ===
local dirs = { left = "left", right = "right", up = "up", down = "down" }
local dir_pl = { left = "w lewo", right = "w prawo", up = "w górę", down = "w dół" }
for key, dir in pairs(dirs) do
    bind(M .. " + " .. key, "Fokus: " .. dir_pl[dir], dsp.focus({ direction = dir }))
    bind(M .. " + CTRL + " .. key, "Przenieś okno: " .. dir_pl[dir], dsp.window.move({ direction = dir }))
end

local resize = { left = { -50, 0 }, right = { 50, 0 }, up = { 0, -50 }, down = { 0, 50 } }
for key, d in pairs(resize) do
    bind(M .. " + SHIFT + " .. key, "Zmień rozmiar okna: " .. dir_pl[key], dsp.window.resize({ x = d[1], y = d[2], relative = true }), { repeating = true })
end

-- === WORKSPACE'Y ===
-- Niestandardowy układ klawiszy (klawiatura Vial). Dawne LSHIFT → SHIFT.
local workspaces = {
    { "SHIFT + 1", 1 },
    { "SHIFT + 2", 2 },
    { "bracketleft", 3 },
    { "SHIFT + 9", 4 },
    { "SHIFT + backslash", 5 },
    { "SHIFT + 7", 6 },
    { "SHIFT + 0", 7 },
    { "bracketright", 8 },
    { "equal", 9 },
    { "minus", 10 },
}
for _, ws in ipairs(workspaces) do
    local key, id = ws[1], ws[2]
    bind(M .. " + " .. key, "Workspace " .. id, dsp.focus({ workspace = id }))
    bind(M .. " + CTRL + " .. key, "Przenieś okno na workspace " .. id, dsp.window.move({ workspace = id }))
end

-- Przenieś bieżący workspace na monitor w danym kierunku
bind(M .. " + CTRL + SHIFT + left", "Przenieś workspace na monitor w lewo", dsp.workspace.move({ monitor = "l" }))
bind(M .. " + CTRL + SHIFT + right", "Przenieś workspace na monitor w prawo", dsp.workspace.move({ monitor = "r" }))
bind(M .. " + CTRL + SHIFT + up", "Przenieś workspace na monitor w górę", dsp.workspace.move({ monitor = "u" }))
bind(M .. " + CTRL + SHIFT + down", "Przenieś workspace na monitor w dół", dsp.workspace.move({ monitor = "d" }))

-- Workspace specjalny (scratchpad)
bind(M .. " + U", "Pokaż/ukryj scratchpad", dsp.workspace.toggle_special("magic"))
bind(M .. " + CTRL + U", "Przenieś okno do scratchpada", dsp.window.move({ workspace = "special:magic" }))

-- Przewijanie istniejących workspace'ów: SUPER + kółko
bind(M .. " + mouse_down", "Następny workspace", dsp.focus({ workspace = "e+1" }))
bind(M .. " + mouse_up", "Poprzedni workspace", dsp.focus({ workspace = "e-1" }))

-- Przesuwanie / zmiana rozmiaru myszą: SUPER + LPM / PPM
-- ⚠️ 0.56.2: znane crashe resize pod Lua (#16118, #16186) — test T5
bind(M .. " + mouse:272", "Przesuń okno myszą", dsp.window.drag(), { mouse = true })
bind(M .. " + mouse:273", "Zmień rozmiar okna myszą", dsp.window.resize(), { mouse = true })

-- === KLAWISZE MULTIMEDIALNE (działają też na ekranie blokady) ===
local media = { repeating = true, locked = true }
bind("XF86AudioRaiseVolume", "Głośniej", exec(v.scripts .. "/volume.sh --inc"), media)
bind("XF86AudioLowerVolume", "Ciszej", exec(v.scripts .. "/volume.sh --dec"), media)
bind("XF86AudioMute", "Wycisz dźwięk", exec(v.scripts .. "/volume.sh --toggle"), media)
bind("XF86AudioMicMute", "Wycisz mikrofon", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), media)
bind("XF86MonBrightnessUp", "Jaśniej", exec(v.scripts .. "/brightness.sh --inc"), media)
bind("XF86MonBrightnessDown", "Ciemniej", exec(v.scripts .. "/brightness.sh --dec"), media)

-- playerctl
bind("XF86AudioNext", "Następny utwór", exec("playerctl next"), { locked = true })
bind("XF86AudioPause", "Odtwórz/pauza", exec("playerctl play-pause"), { locked = true })
bind("XF86AudioPlay", "Odtwórz/pauza", exec("playerctl play-pause"), { locked = true })
bind("XF86AudioPrev", "Poprzedni utwór", exec("playerctl previous"), { locked = true })
