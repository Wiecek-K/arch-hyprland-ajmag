-- Skróty klawiszowe. Ładowane zaraz po env — błąd w innym module nie odbierze klawiatury.
-- Format: "MOD + MOD + klawisz". Tylko SHIFT/CTRL/ALT/SUPER (LSHIFT = błąd w Lua).

local v = require("configs.vars")
local fn = require("configs.functions")
local dsp = hl.dsp
local M = v.mainMod

local function bind(keys, action, opts)
    hl.bind(keys, action, opts)
end

local function exec(cmd, rules)
    return dsp.exec_cmd(cmd, rules)
end

-- === APLIKACJE I SESJA ===
bind(M .. " + Return", exec(v.terminal))
bind(M .. " + SHIFT + Return", exec(v.terminal, { float = true, size = { 800, 550 } }))
bind(M .. " + Q", dsp.window.close())
bind("CTRL + ALT + Delete", dsp.exit())
bind(M .. " + E", exec(v.fileManager))
bind(M .. " + Space", dsp.window.float())
bind(M .. " + D", exec(v.menu))
bind(M .. " + O", dsp.window.pseudo()) -- dwindle
bind(M .. " + J", dsp.layout("togglesplit"))
bind(M .. " + R", exec(v.scripts .. "/wbrestart.sh"))
bind(M .. " + B", exec('xdg-open "https://"')) -- domyślna przeglądarka
bind(M .. " + L", exec(v.scripts .. "/Wlogout.sh"))
bind(M .. " + SHIFT + F", dsp.window.fullscreen())
bind(M .. " + CTRL + S", exec(v.scripts .. "/screenshot.sh"))
bind(M .. " + W", exec(v.scripts .. "/wppicker.sh"))
bind(M .. " + SHIFT + Q", exec(v.scripts .. "/KillActiveProcess.sh"))
bind(M .. " + C", exec("hyprpicker -a"))
bind(M .. " + CTRL + B", exec(v.scripts .. "/WaybarStyles.sh"))
bind(M .. " + ALT + B", exec(v.scripts .. "/WaybarLayout.sh"))
bind(M .. " + H", exec("pkill -SIGUSR1 waybar")) -- ukryj Waybar
bind(M .. " + SHIFT + E", exec("kitty yazi"))
bind(M .. " + F1", fn.gamemode) -- gamemode: przełącza efekty wizualne

-- === FOKUS, PRZENOSZENIE, ROZMIAR ===
local dirs = { left = "left", right = "right", up = "up", down = "down" }
for key, dir in pairs(dirs) do
    bind(M .. " + " .. key, dsp.focus({ direction = dir }))
    bind(M .. " + CTRL + " .. key, dsp.window.move({ direction = dir }))
end

local resize = { left = { -50, 0 }, right = { 50, 0 }, up = { 0, -50 }, down = { 0, 50 } }
for key, d in pairs(resize) do
    bind(M .. " + SHIFT + " .. key, dsp.window.resize({ x = d[1], y = d[2], relative = true }), { repeating = true })
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
    bind(M .. " + " .. key, dsp.focus({ workspace = id }))
    bind(M .. " + CTRL + " .. key, dsp.window.move({ workspace = id }))
end

-- Przenieś bieżący workspace na monitor w danym kierunku
bind(M .. " + CTRL + SHIFT + left", dsp.workspace.move({ monitor = "l" }))
bind(M .. " + CTRL + SHIFT + right", dsp.workspace.move({ monitor = "r" }))
bind(M .. " + CTRL + SHIFT + up", dsp.workspace.move({ monitor = "u" }))
bind(M .. " + CTRL + SHIFT + down", dsp.workspace.move({ monitor = "d" }))

-- Workspace specjalny (scratchpad)
bind(M .. " + U", dsp.workspace.toggle_special("magic"))
bind(M .. " + CTRL + U", dsp.window.move({ workspace = "special:magic" }))

-- Przewijanie istniejących workspace'ów: SUPER + kółko
bind(M .. " + mouse_down", dsp.focus({ workspace = "e+1" }))
bind(M .. " + mouse_up", dsp.focus({ workspace = "e-1" }))

-- Przesuwanie / zmiana rozmiaru myszą: SUPER + LPM / PPM
-- ⚠️ 0.56.2: znane crashe resize pod Lua (#16118, #16186) — test T5
bind(M .. " + mouse:272", dsp.window.drag(), { mouse = true })
bind(M .. " + mouse:273", dsp.window.resize(), { mouse = true })

-- === KLAWISZE MULTIMEDIALNE (działają też na ekranie blokady) ===
local media = { repeating = true, locked = true }
bind("XF86AudioRaiseVolume", exec(v.scripts .. "/volume.sh --inc"), media)
bind("XF86AudioLowerVolume", exec(v.scripts .. "/volume.sh --dec"), media)
bind("XF86AudioMute", exec(v.scripts .. "/volume.sh --toggle"), media)
bind("XF86AudioMicMute", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), media)
bind("XF86MonBrightnessUp", exec(v.scripts .. "/brightness.sh --inc"), media)
bind("XF86MonBrightnessDown", exec(v.scripts .. "/brightness.sh --dec"), media)

-- playerctl
bind("XF86AudioNext", exec("playerctl next"), { locked = true })
bind("XF86AudioPause", exec("playerctl play-pause"), { locked = true })
bind("XF86AudioPlay", exec("playerctl play-pause"), { locked = true })
bind("XF86AudioPrev", exec("playerctl previous"), { locked = true })
