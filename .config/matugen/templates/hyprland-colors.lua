-- Generowane przez matugen z ~/.config/matugen/templates/hyprland-colors.lua — nie edytować ręcznie.
return {
    image = "{{image}}",
<* for name, value in colors *>
    {{name}} = "rgba({{value.default.hex_stripped}}ff)",
<* endfor *>
}
