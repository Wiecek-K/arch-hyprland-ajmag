-- Klawiatura, mysz, touchpad, gesty.
hl.config({
    input = {
        kb_layout      = "pl",
        follow_mouse   = 1,
        sensitivity    = 0, -- -1.0 .. 1.0, 0 = bez zmian
        accel_profile  = "flat",
        force_no_accel = true,
        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
