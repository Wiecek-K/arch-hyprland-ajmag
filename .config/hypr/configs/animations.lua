-- Krzywe i animacje. Współrzędne beziera muszą być w [-1, 2].
local function bezier(name, x0, y0, x1, y1)
    hl.curve(name, { type = "bezier", points = { { x0, y0 }, { x1, y1 } } })
end

bezier("slow",     0,   0.85, 0.3, 1)
bezier("wind",     0.05, 0.9, 0.1, 1.05)
bezier("linear",   0,   0,    1,   1)
bezier("overshot", 0.7, 0.6,  0.1, 1.1)
bezier("bounce",   1.1, 1.6,  0.1, 0.85)

hl.config({ animations = { enabled = true } })

-- Kolejność jak w hyprlang: `windows` na końcu (ustawia rodzica po dzieciach).
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 3, bezier = "slow",     style = "popin" })
hl.animation({ leaf = "windowsOut",  enabled = false })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "wind",     style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 1, bezier = "linear" })
hl.animation({ leaf = "fade",        enabled = true, speed = 5, bezier = "overshot" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5, bezier = "wind" })
hl.animation({ leaf = "windows",     enabled = true, speed = 5, bezier = "bounce",   style = "popin" })
