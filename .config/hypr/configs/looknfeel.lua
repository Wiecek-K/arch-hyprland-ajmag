-- Wygląd: ramki, odstępy, blur, zaokrąglenia, layouty, misc.
-- Kolory z colors.lua (matugen). Brak/uszkodzony plik → stała paleta, config działa dalej.

local fallback = {
    primary         = "rgba(a2c9fdff)",
    secondary       = "rgba(bbc7dbff)",
    outline_variant = "rgba(43474eff)",
    surface         = "rgba(111418ff)",
}

local ok, c = pcall(require, "colors")
-- safe-require zwraca pustą tabelę przy błędzie wykonania, więc sprawdzamy zawartość
if not ok or type(c) ~= "table" or not c.primary then
    c = fallback
end

hl.config({
    general = {
        gaps_in     = 4,
        gaps_out    = { top = 2, right = 6, bottom = 4, left = 6 },
        border_size = 3,
        col = {
            active_border   = { colors = { c.primary, c.secondary, c.secondary }, angle = 45 },
            inactive_border = c.outline_variant,
        },
        resize_on_border = false,
        allow_tearing    = true,
        layout           = "dwindle",
    },

    decoration = {
        rounding         = 16,
        rounding_power   = 2,
        active_opacity   = 1.0,
        inactive_opacity = 0.8,
        -- Faza C ticket 09 (B11 wpis 10, end-4 dots-hyprland@2f0c8bf general.lua): duży, miękki, prawie
        -- przezroczysty cień, tylko pod oknami pływającymi (kafelkowe: reguła no-shadow-tiled w rules.lua).
        -- render_power 4 = maksimum Hyprlanda 0.57 (end-4 ma 10, odrzucane). Warstwy i popupy Ajmashella cienia
        -- Hyprlanda nie dostają (layer_rule nie ma pola cienia); ich cień rysuje shell (ticket C13).
        shadow = {
            enabled      = true,
            range        = 32,
            offset       = { 0, 2 },
            render_power = 4,
            color        = "rgba(00000040)",
        },
        blur = {
            enabled           = true,
            size              = 10,
            passes            = 2,
            noise             = 0.02,
            contrast          = 0.6,
            ignore_opacity    = true,
            new_optimizations = true,
            special           = false,
            popups            = true,
            xray              = false,
            vibrancy          = 0.42,
            vibrancy_darkness = 0.13,
        },
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper    = 0,
        disable_hyprland_logo      = true,
        focus_on_activate          = true,
        initial_workspace_tracking = 2,
        -- kolor tła pod tapetą: ewentualny flash przy reloadzie nie będzie czarny
        background_color           = c.surface,
        -- awaryjne `hyprctl keyword misc:allow_session_lock_restore 1` nie działa pod Lua → na stałe
        allow_session_lock_restore = true,
    },

    render = {
        new_render_scheduling = false,
    },

    debug = {
        vfr = true,
    },

    cursor = {
        inactive_timeout    = 10,
    },
})
