// Icons of tray apps from the same theme as GTK (gtk-icon-theme-name in ~/.config/gtk-3.0/settings.ini);
// without it Qt 6 has no icon theme and udiskie's icon is missing (ticket 09). Needs a full restart, not a reload.
//@ pragma IconTheme Ajmashell-Dark
// Ajmashell — root of the shell. Run: qs -c ajmashell
// Layout modelled on serpantinum (src/quickshell/Shell.qml):
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// Copyright (C) 2026 Illia Miroshnichenko — AGPL-3.0-or-later
// Changes: `import qs.<dir>` instead of hand-written qmldir + relative imports.
// SPDX-License-Identifier: AGPL-3.0-or-later

import Quickshell
import qs.bar
import qs.control
import qs.keybinds
import qs.launcher
import qs.notifications
import qs.osd
import qs.power
import qs.wallpaper

ShellRoot {
    Bar {
        id: bar
        onControlRequested: screenName => control.toggle(screenName)
    }

    // Centrum sterowania (ticket 14): opened by the bell; its Wi-Fi / BT rows open the Orbita on the same screen
    ControlCenter {
        id: control
        onOrbitRequested: (tab, screenName) => bar.orbitRequested(tab, screenName)
        onPowerRequested: screenName => power.toggle(screenName)
    }

    // Panel zasilania (ticket 18): SUPER+L (qs ipc call power toggle) and the Centrum's power button
    PowerPanel {
        id: power
        onOpenChanged: if (open)
            control.closeAtOnce() // SUPER+L with the Centrum open: no slide over the backdrop (ticket 35)
    }

    NotificationPopups {}

    // OSD of the volume and brightness keys (ticket 15): volume.sh / brightness.sh call it over IPC
    Osd {}

    WallpaperPicker {}

    Launcher {}

    // Keybinds (ticket 20): SUPER+K and "Keybinds" in the launcher's app list, both over IPC
    Keybinds {}
}
