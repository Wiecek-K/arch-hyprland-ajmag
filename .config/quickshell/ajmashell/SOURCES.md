# Ajmashell: license and sources

Ajmashell is a Quickshell configuration (`qs -c ajmashell`): Bar, notifications, Centrum sterowania (control centre),
launcher, Orbita (Wi-Fi and Bluetooth popup), wallpaper carousel, power panel, OSD and a keybinds viewer.

Copyright (C) 2026 Wiecek-K

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any
later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See [`LICENSE`](LICENSE) for the full
text of the GNU Affero General Public License, version 3.

The license covers this directory (`.config/quickshell/ajmashell/`) only. The rest of the dotfiles repository keeps
its own terms. A file whose header names another license (`SPDX-License-Identifier`) is under that license.

## Code copied from other projects

Each of these files keeps a header with the source (`URL@commit`), the original copyright notice and a list of our
changes.

| Source | License | Our files |
|---|---|---|
| [ilyamiro/serpantinum](https://github.com/ilyamiro/serpantinum)@`c34fb82`, Copyright (C) 2026 Illia Miroshnichenko | AGPL-3.0-or-later | `shell.qml`, `bar/Bar.qml`, `notifications/NotificationPopups.qml`, `singletons/notifications/Notifications.qml`, `launcher/Launcher.qml`, `launcher/launcher.mjs`, `orbit/Orbit.qml`, `orbit/orbit.mjs`, `wallpaper/WallpaperPicker.qml`, `wallpaper/carousel.mjs`, `wallpaper/indexer.py` |
| [AvengeMedia/DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)@`9dc5b2c`, Copyright (c) 2025 Avenge Media LLC | MIT (notice below) | `bar/workspaces.mjs` (`luaString`, `luaValue`) |

## Ideas only (own implementation, no code copied)

The file headers name the exact source file and commit.

| Source | License | Idea used in |
|---|---|---|
| [ilyamiro/serpantinum](https://github.com/ilyamiro/serpantinum) | AGPL-3.0-or-later | tray click mapping, Wi-Fi signal steps, notification card, media island, media popup and player choice, workspaces |
| [AvengeMedia/DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) | MIT | audio volume clamp and device icons, tray submenus, wheel accumulator |
| [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) | GPL-3.0 | theme loader (`FileView` on matugen JSON), unread badge on the bell, control centre sliders, OSD, calculator through `qalc` |
| [caelestia-dots/shell](https://github.com/caelestia-dots/shell) | GPL-3.0 | control centre panel layout, power panel buttons, calendar month wheel |
| [basecamp/omarchy](https://github.com/basecamp/omarchy) | MIT | keybinds viewer |

## MIT notice (DankMaterialShell)

```
MIT License

Copyright (c) 2025 Avenge Media LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
