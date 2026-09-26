-- Zmienne środowiskowe (dawne `env = NAME,value`).

-- Kursor
hl.env("XCURSOR_SIZE", "36")
hl.env("XCURSOR_THEME", "Vimix-cursors")
hl.env("HYPRCURSOR_SIZE", "36")
hl.env("HYPRCURSOR_THEME", "Vimix-hyprcursor")

-- GPU: Intel primary (celowo od 2026-06-24), NVIDIA jako druga karta
hl.env("AQ_DRM_DEVICES", "/dev/dri/intel-card:/dev/dri/nvidia-card")
hl.env("LIBVA_DRIVER_NAME", "iHD")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Backendy toolkitów
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- Qt
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")

hl.env("MOZ_DRM_DEVICE", "/dev/dri/renderD129")

-- VRR/G-Sync wyłączone dla stabilności NVIDIA+Wayland (źródło migotania/zawieszeń po wybudzeniu)
hl.env("__GL_GSYNC_ALLOWED", "0")
hl.env("__GL_VRR_ALLOWED", "0")
hl.env("NV_REQ_S_PL", "1")
