#!/bin/sh
# Włącza ekrany po wybudzeniu (hypridle after_sleep_cmd). Składnia Lua (Hyprland 0.56+ z hyprland.lua).
# Dokładnie "on": nieznana wartość NIE daje błędu, tylko przełącza (toggle) — mogłaby wyłączyć ekran.
exec hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
