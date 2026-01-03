#!/bin/bash

# Minimalny dozwolony poziom jasności
MIN_BRIGHTNESS=5

# Pobierz aktualną jasność
current_brightness=$(brightnessctl -m | cut -d, -f4 | sed 's/%//')

# Jeśli jest poniżej minimum, ustaw na minimum
if [ "$current_brightness" -lt "$MIN_BRIGHTNESS" ]; then
    brightnessctl set "${MIN_BRIGHTNESS}%"
fi
