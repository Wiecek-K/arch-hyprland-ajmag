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
bind(M .. " + SHIFT + Return", "Floating terminal", exec(v.terminal, { float = true, size = { 800, 550 } }))
bind(M .. " + Q", "Close window", dsp.window.close())
bind("CTRL + ALT + Delete", "Exit Hyprland", dsp.exit())
bind(M .. " + E", "File manager", exec(v.fileManager))
bind(M .. " + Space", "Toggle floating", dsp.window.float())
bind(M .. " + D", "App launcher", exec(v.menu))
bind(M .. " + O", "Toggle pseudotile", dsp.window.pseudo()) -- dwindle
bind(M .. " + J", "Toggle split direction", dsp.layout("togglesplit"))
bind(M .. " + R", "Restart Waybar", exec(v.scripts .. "/wbrestart.sh"))
bind(M .. " + B", "Web browser", exec('xdg-open "https://"')) -- domyślna przeglądarka
bind(M .. " + L", "Power menu", exec(v.scripts .. "/Wlogout.sh"))
bind(M .. " + SHIFT + F", "Fullscreen", dsp.window.fullscreen())
bind(M .. " + CTRL + S", "Screenshot", exec(v.scripts .. "/screenshot.sh"))
bind(M .. " + W", "Change wallpaper", exec(v.scripts .. "/wppicker.sh"))
bind(M .. " + SHIFT + Q", "Kill active window process", exec(v.scripts .. "/KillActiveProcess.sh"))
bind(M .. " + C", "Color picker", exec("hyprpicker -a"))
bind(M .. " + CTRL + B", "Waybar style", exec(v.scripts .. "/WaybarStyles.sh"))
bind(M .. " + ALT + B", "Waybar layout", exec(v.scripts .. "/WaybarLayout.sh"))
bind(M .. " + H", "Toggle Waybar", exec("pkill -SIGUSR1 waybar")) -- ukryj Waybar
bind(M .. " + SHIFT + E", "Yazi in terminal", exec("kitty yazi"))
bind(M .. " + F1", "Game mode (visual effects)", fn.gamemode) -- gamemode: przełącza efekty wizualne

-- === FOKUS, PRZENOSZENIE, ROZMIAR ===
local dirs = { left = "left", right = "right", up = "up", down = "down" }
for key, dir in pairs(dirs) do
    bind(M .. " + " .. key, "Focus " .. dir, dsp.focus({ direction = dir }))
    bind(M .. " + CTRL + " .. key, "Move window " .. dir, dsp.window.move({ direction = dir }))
end

local resize = { left = { -50, 0 }, right = { 50, 0 }, up = { 0, -50 }, down = { 0, 50 } }
for key, d in pairs(resize) do
    bind(M .. " + SHIFT + " .. key, "Resize window " .. key, dsp.window.resize({ x = d[1], y = d[2], relative = true }), { repeating = true })
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
    bind(M .. " + CTRL + " .. key, "Move window to workspace " .. id, dsp.window.move({ workspace = id }))
end

-- Przenieś bieżący workspace na monitor w danym kierunku
bind(M .. " + CTRL + SHIFT + left", "Move workspace to left monitor", dsp.workspace.move({ monitor = "l" }))
bind(M .. " + CTRL + SHIFT + right", "Move workspace to right monitor", dsp.workspace.move({ monitor = "r" }))
bind(M .. " + CTRL + SHIFT + up", "Move workspace to upper monitor", dsp.workspace.move({ monitor = "u" }))
bind(M .. " + CTRL + SHIFT + down", "Move workspace to lower monitor", dsp.workspace.move({ monitor = "d" }))

-- Workspace specjalny (scratchpad)
bind(M .. " + U", "Toggle scratchpad", dsp.workspace.toggle_special("magic"))
bind(M .. " + CTRL + U", "Move window to scratchpad", dsp.window.move({ workspace = "special:magic" }))

-- Przewijanie istniejących workspace'ów: SUPER + kółko
bind(M .. " + mouse_down", "Next workspace", dsp.focus({ workspace = "e+1" }))
bind(M .. " + mouse_up", "Previous workspace", dsp.focus({ workspace = "e-1" }))

-- Przesuwanie / zmiana rozmiaru myszą: SUPER + LPM / PPM
-- ⚠️ 0.56.2: znane crashe resize pod Lua (#16118, #16186) — test T5
bind(M .. " + mouse:272", "Move window with mouse", dsp.window.drag(), { mouse = true })
bind(M .. " + mouse:273", "Resize window with mouse", dsp.window.resize(), { mouse = true })

-- === KLAWISZE MULTIMEDIALNE (działają też na ekranie blokady) ===
local media = { repeating = true, locked = true }
bind("XF86AudioRaiseVolume", "Volume up", exec(v.scripts .. "/volume.sh --inc"), media)
bind("XF86AudioLowerVolume", "Volume down", exec(v.scripts .. "/volume.sh --dec"), media)
bind("XF86AudioMute", "Mute audio", exec(v.scripts .. "/volume.sh --toggle"), media)
bind("XF86AudioMicMute", "Mute microphone", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), media)
bind("XF86MonBrightnessUp", "Brightness up", exec(v.scripts .. "/brightness.sh --inc"), media)
bind("XF86MonBrightnessDown", "Brightness down", exec(v.scripts .. "/brightness.sh --dec"), media)

-- playerctl
bind("XF86AudioNext", "Next track", exec("playerctl next"), { locked = true })
bind("XF86AudioPause", "Play/pause", exec("playerctl play-pause"), { locked = true })
bind("XF86AudioPlay", "Play/pause", exec("playerctl play-pause"), { locked = true })
bind("XF86AudioPrev", "Previous track", exec("playerctl previous"), { locked = true })
