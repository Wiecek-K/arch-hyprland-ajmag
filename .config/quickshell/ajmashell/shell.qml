// Icons of tray apps from the same theme as GTK (gtk-icon-theme-name in ~/.config/gtk-3.0/settings.ini);
// without it Qt 6 has no icon theme and udiskie's icon is missing (ticket 09). Needs a full restart, not a reload.
//@ pragma IconTheme Colloid-Teal-Dark
// Ajmashell — root of the shell. Run: qs -c ajmashell
// Layout modelled on serpantinum (src/quickshell/Shell.qml):
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// Copyright (C) 2026 Illia Miroshnichenko — AGPL-3.0-or-later
// Changes: `import qs.<dir>` instead of hand-written qmldir + relative imports.
// SPDX-License-Identifier: AGPL-3.0-or-later

import Quickshell
import qs.bar
import qs.launcher
import qs.notifications
import qs.wallpaper

ShellRoot {
    Bar {}

    NotificationPopups {}

    WallpaperPicker {}

    Launcher {}
}
