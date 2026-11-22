-- Zmienne środowiskowe (dawne `env = NAME,value`).

-- Kursor
hl.env("XCURSOR_SIZE", "36")
hl.env("XCURSOR_THEME", "Vimix-cursors")
hl.env("HYPRCURSOR_SIZE", "36")
hl.env("HYPRCURSOR_THEME", "Vimix-hyprcursor")

-- GPU: tu nic. Bez AQ_DRM_DEVICES Hyprland sam wykrywa karty, libva sama dobiera sterownik VA-API
-- (amdgpu → radeonsi, i915 → iHD). Ustawienia konkretnej maszyny (AQ_DRM_DEVICES, LIBVA_DRIVER_NAME,
-- MOZ_DRM_DEVICE, zmienne NVIDII) idą do host.lua (zobacz hyprland.lua).

-- Backendy toolkitów
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
-- SDL_VIDEODRIVER celowo nieustawione: SDL3 sam wybiera Wayland, a globalne "wayland" psuje gry z własnym SDL
-- i overlay Steam (Valve, steam-runtime #754/#716; ticket 50, 2026-10-16)
hl.env("CLUTTER_BACKEND", "wayland")

-- Qt
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
