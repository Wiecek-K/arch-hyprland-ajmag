# Arch Linux + Hyprland (AJMAG Configuration)

![Arch Linux](https://img.shields.io/badge/Arch_Linux-DISTRO-1793d1?style=for-the-badge&logo=arch-linux)
![Hyprland](https://img.shields.io/badge/Hyprland-WM-00a4a6?style=for-the-badge&logo=hyprland)
![Quickshell](https://img.shields.io/badge/Quickshell-SHELL-7e57c2?style=for-the-badge)
![Matugen](https://img.shields.io/badge/Matugen-THEMING-ff0055?style=for-the-badge)

A highly customized, stable, and performance-oriented Hyprland environment. This configuration prioritizes **text clarity** ("High Visibility Mode") and **dynamic theming**.
The Hyprland config is written in **Lua** (`.config/hypr/hyprland.lua`), the format Hyprland uses since 0.55 — upstream removes the old hyprlang `.conf` format in 0.57, so this config is ready for it.

---

## 🌟 Key Features

### 🐚 Shell: Ajmashell (Quickshell)
Own shell written in [Quickshell](https://quickshell.org) (QML), in `.config/quickshell/ajmashell/`. One process replaces Waybar, swaync, rofi and wlogout, all in Matugen colors:
*   **Bar:** islands for tray, media, clock with calendar, workspaces, volume and microphone, Bluetooth / Wi-Fi / notifications.
*   **Orbit:** Wi-Fi and Bluetooth popup (scan, connect, pair, battery, headset profile).
*   **Control Center:** volume and brightness sliders, audio outputs, per-app volume, grouped notifications with actions, silent mode, power buttons.
*   **Launcher** (`Super + D`): apps, open windows, calculator (`=`).
*   **Wallpaper carousel** (`Super + W`): sets the wallpaper and the colors.
*   **Power panel** (`Super + L`), **OSD** for volume and brightness keys, **Keybinds viewer** (`Super + K`).
*   **Theme Center** (separate app, [ajmashell-theme-center](https://github.com/Wiecek-K/ajmashell-theme-center)): a window to tune the palette recipe for your wallpapers and the look of the big popups, with a live preview before you save.

### 🎨 Visual Identity
*   **Dynamic Theming:** System-wide colors generated from your wallpaper using `Matugen`.
    *   *Affected apps:* Ajmashell (Quickshell), Hyprland borders, hyprlock, Kitty, GTK 3/4 apps, folder icons, Spotify (via Spicetify, optional), Zen Browser (via userChrome.css, optional).
*   **Typography:** Global usage of **Atkinson Hyperlegible** (UI) and **Atkinson Hyperlegible Mono** (Shell/Terminal/Code) for maximum readability. In Nerd Fonts the mono family is called `AtkynsonMono Nerd Font` (package `otf-atkinsonhyperlegiblemono-nerd`); use that name if you set the font in another app.
*   **High Visibility Mode** (window rules in `.config/hypr/configs/rules.lua`, active / inactive opacity):
    *   **Active Windows:** 100% opacity + 3px gradient border (primary → secondary). Other windows fade to 80% when inactive.
    *   **Text-Heavy Apps** stay readable when inactive: browsers and messengers (Zen, Firefox, Chromium, Discord/Vesktop, Telegram, Slack) 100% / 95%, notes (Obsidian, Logseq) 98% / 94%, code editors (VS Code, JetBrains, Gedit) 97% / 91%.
    *   **Background Apps:** Kitty 89% / 70%, Nautilus 90% / 70%, Spotify 90% / 75%; settings tools (network, Bluetooth, disks) 80% and floating.
    *   **Video players** (mpv, VLC): always 100%, no blur, floating.

<img width="1918" height="1078" alt="image" src="https://github.com/user-attachments/assets/cb734e5d-62e6-49d3-9b4f-ccea77971446" />
<img width="1920" height="1076" alt="image" src="https://github.com/user-attachments/assets/9e62d346-622d-49d1-8736-a9c9b95bf142" />
<img width="1916" height="1078" alt="image" src="https://github.com/user-attachments/assets/e773cce5-320e-49f8-a44f-4b0f338ae9b8" />
<img width="1917" height="1070" alt="image" src="https://github.com/user-attachments/assets/466763b2-cf65-4771-8370-a36f2bc5e9f2" />
<img width="1917" height="1066" alt="image" src="https://github.com/user-attachments/assets/00501aa3-9755-4230-91c5-dbb38dfe03b3" />
<img width="1922" height="1081" alt="image" src="https://github.com/user-attachments/assets/ba5a8f3e-c983-49a6-abe3-40853f9923b2" />

---

## 📦 Installation

There is no installer: this repo is a set of files to copy. It assumes a working Arch Linux with Hyprland; drivers and everyday applications stay your choice.

### 0. Before You Start
*   Start Hyprland through uwsm (the "Hyprland (uwsm-managed)" session in your display manager, or `uwsm start hyprland.desktop` from a TTY): Ajmashell is a systemd user service and gets the session's variables from uwsm. Without uwsm the bar does not start. Check with `systemctl --user is-active wayland-wm@hyprland.desktop` (`active`).
*   Update the system first (`sudo pacman -Syu`): with an old package database the mirrors answer 404 and the install fails.
*   AUR packages need an AUR helper, e.g. [yay](https://github.com/Jguer/yay).
*   Ajmashell is the notification daemon, the bar and the launcher. Another notification daemon takes the notifications before it, so remove it if you have one (`dunst`, `mako`, `swaync`; the archinstall Hyprland profile installs `dunst`). Bars and launchers like Waybar or wofi can stay installed, but take them out of your autostart.

### 1. Clone the Repository
```bash
git clone https://github.com/Wiecek-K/arch-hyprland-ajmag.git
cd arch-hyprland-ajmag
```

### 2. Packages
[`packages.txt`](packages.txt) lists what the config needs, grouped by the part that uses it. The first command installs the official packages, the second the AUR ones.
```bash
awk '!/^#/ && NF && !/AUR|optional/ {print $1}' packages.txt | sudo pacman -S --needed -
awk '!/^#/ && /AUR/ && !/optional/ {print $1}' packages.txt | yay -S --needed -
sudo systemctl enable --now bluetooth
```
Lines tagged `optional` are not installed by these commands; add the ones you want by name.

### 3. Config Files
The folders of the apps this config owns are moved aside first; every other file that would be overwritten keeps its old copy as `<name>.~1~`. Your machine files (`monitors.lua`, `host.lua`), if you had them, move with the old `hypr` folder: copy them back into `~/.config/hypr/` (see Monitor Configuration below).
```bash
for d in hypr quickshell kitty matugen spicetify; do [ -e ~/.config/$d ] && mv ~/.config/$d ~/.config/$d.bak.$(date +%s); done
cp -r --backup=numbered .config/. ~/.config/
cp --backup=numbered .zshrc ~/
mkdir -p ~/.local/share ~/.local/state/ajmashell
cp -r --backup=numbered .local/share/. ~/.local/share/
systemctl --user daemon-reload
```
`~/.local/state/ajmashell` holds the colours Matugen writes for the shell; it must exist before the first wallpaper is set.
The `.zshrc` is for zsh (with oh-my-zsh); to make zsh your shell: `chsh -s /usr/bin/zsh` (takes effect at the next login).

### 4. Cursor and GTK Settings
On Wayland GTK apps read these settings, not `settings.ini`. Without `prefer-dark` Zen and GTK 4 apps stay light (dark text on a dark background).
```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface font-name 'Atkinson Hyperlegible 12'
gsettings set org.gnome.desktop.interface cursor-theme 'Vimix-cursors'
gsettings set org.gnome.desktop.interface cursor-size 24
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal kitty   # from nautilus-open-any-terminal (AUR, in packages.txt)
```

### 5. Zen Browser (optional)
Start Zen once first, so it creates its profile (the `Default=` line of `~/.config/zen/installs.ini`). Then:
```bash
PROFILE=~/.config/zen/"$(sed -n 's/^Default=//p' ~/.config/zen/installs.ini 2>/dev/null | head -n 1)"
if [ "$PROFILE" != ~/.config/zen/ ] && [ -d "$PROFILE" ]; then
    cp -r --backup=numbered zen/profile/. "$PROFILE/"
    rm -rf ~/.local/state/ajmashell/zen-chrome && ln -s "$PROFILE/chrome" ~/.local/state/ajmashell/zen-chrome
else
    echo "No Zen profile: start Zen once, then run these lines again"
fi
```
`user.js` turns on `userChrome.css`; the link is where Matugen writes Zen's colours. Live colours without a browser restart need two files in the browser's own folder (root, `sudo`); skip them and the colours change on the next Zen start:
```bash
sudo cp -r zen/opt/. /opt/zen-browser-bin/
```

### 6. First Run
1.  Log out and back in (or reboot). With more than one monitor, or a wrong resolution, set the layout in `nwg-displays` (see Monitor Configuration below).
2.  Put wallpapers in `~/Pictures/wallpapers` (`mkdir -p ~/Pictures/wallpapers`): your own images, or my curated set from [Google Drive](https://drive.google.com/drive/folders/1jm_ue4uFqiIk5MdADcdGHq6Q86uCa-s4) (`CREDITS.md` there lists the authors). Drive downloads the folder as a zip; unzip it and move the images straight into `~/Pictures/wallpapers`, because the carousel does not look into subfolders.
3.  Press `Super + W` to pick a wallpaper; this generates the first colour scheme.
    Workspaces are on custom keys, not on the number keys: see “Important Note on Keyboard Layout” below.
4.  Restart Zen once, so it loads the files from step 5.

### 7. Spotify with Spicetify (optional)
Spicetify themes Spotify with the wallpaper colours (theme `text`, extension `live-colors.js` from `.config/spicetify`). Do it after the first wallpaper (step 6): Matugen writes the theme's colours then. The order matters:
```bash
spotify    # start it once and log in: this creates ~/.config/spotify/prefs; then quit it (pkill spotify), closing the window leaves it running
spicetify config current_theme text color_scheme Spicetify extensions live-colors.js overwrite_assets 1
sudo chmod a+wr /opt/spotify && sudo chmod -R a+rwX /opt/spotify/Apps
spicetify backup apply
```
After a Spotify update run the last two lines again (the `.zshrc` function `my-fix-spicetify` does it). Without Spicetify nothing else changes.
Spicetify patches the one Spotify in `/opt`, so on a computer with several accounts only one account gets Spotify colours from its wallpaper; the others see that account's colours.

### 8. Theme Center (optional)
[Ajmashell Theme Center](https://github.com/Wiecek-K/ajmashell-theme-center) is a separate app for tuning how the palette is picked from your wallpapers and the look of the big popups. It installs from its own repo:
```bash
git clone https://github.com/Wiecek-K/ajmashell-theme-center.git ~/Projects/ajmashell-theme-center
cd ~/Projects/ajmashell-theme-center && ./install.sh
```
Then start "Ajmashell Theme Center" from the launcher (`Super + D`). Its README lists what else it needs (`zenity` for its file dialogs).

---

## 🖥️ Monitor Configuration

Monitor layout lives in `~/.config/hypr/monitors.lua`, generated by **`nwg-displays`** (GUI). It contains hardware-specific port names (e.g., `DP-1`, `HDMI-A-2`), which differ on a new machine.

*   The repo has no `monitors.lua`: until you save a layout in `nwg-displays`, Hyprland uses `preferred, auto` for every monitor.
*   `hyprland.lua` loads the file with `pcall`, so a broken or missing file does not stop the config.
*   **Wrong layout or a black screen:** switch to a TTY (`Ctrl+Alt+F3`), empty the file (`echo "" > ~/.config/hypr/monitors.lua`), return to Hyprland and set the layout again in `nwg-displays`.

---

## ⌨️ Keybinds & Configuration

All keybindings are defined and can be modified in:
> **`~/.config/hypr/configs/keybinds.lua`**

`Super + K` opens a searchable list of all keybindings with their descriptions.

### ⚠️ Important Note on Keyboard Layout
The workspace switching binds in this configuration use specific symbols (e.g., `bracketleft`, `minus`, `equal`) instead of standard numbers.

**Reason:** This setup is tailored for a **custom keyboard layout** where number keys might behave differently.

**Recommendation:** If you are using a standard layout (QWERTY/ANSI/ISO), **you should edit `keybinds.lua` and revert the workspace binds to standard numbers (`1`, `2`, `3`...)** to ensure they work as expected.

---

## 🛠️ Customizations Detail

### Shell (Ajmashell)
*   Quickshell config `ajmashell`, run by the systemd user service `.config/systemd/user/ajmashell.service` (restarted on failure; `Super + R` restarts it by hand).
*   **Colors:** Matugen writes `~/.local/state/ajmashell/colors.json`; the shell reloads it live, without a restart.
*   **License:** Ajmashell is licensed under **AGPL-3.0-or-later** — see [`LICENSE`](.config/quickshell/ajmashell/LICENSE). Parts of it are copied from or inspired by other Quickshell configs; [`SOURCES.md`](.config/quickshell/ajmashell/SOURCES.md) lists them with their licenses. The license covers only `.config/quickshell/ajmashell/`, not the rest of this repository.

### Zen Browser
*   Uses `userChrome.css` (`zen/profile/chrome/`, enabled by `zen/profile/user.js`) to import `matugen-colors.css` at startup.
*   **Live colours:** Firefox reads `userChrome.css` only at startup, so the AutoConfig script `zen/opt/config.js` (copied into `/opt/zen-browser-bin/` with `sudo`, step 5 of the installation) re-registers `matugen-colors.css` as a user style sheet when matugen's post_hook connects to its Unix socket (`$XDG_RUNTIME_DIR/ajmashell-zen.sock`, via `socat`) after each wallpaper change — no browser restart, no polling. Roll back: delete `/opt/zen-browser-bin/config.js` and `/opt/zen-browser-bin/defaults/pref/autoconfig.js`, restart Zen.

### Terminal (Kitty)
*   **Style:** Powerline tab bar (hidden if only 1 tab), Beam cursor.
*   **Colors:** Tab bar uses muted/pastel versions of the primary color to avoid visual fatigue.
*   **Start:** Clean start (no fetch tools).

### Editors
*   **Nano:** Configured with line numbers and muted UI colors.
*   **Gedit:** Includes a ZSH function to automatically detach the process from the terminal, keeping the shell usable.

---

## 📂 Repository Structure

```text
.
├── .config/                  # Copy to ~/.config/ (Hyprland, Ajmashell, Kitty, Matugen, GTK/Qt, Spicetify, ...)
├── .local/share/
│   ├── applications/         # Desktop entry: Ajmashell Keybinds
│   ├── dbus-1/services/      # Nautilus D-Bus start refused while the portal starts (avoids a 25 s wait at login)
│   └── icons/                # Cursor themes (Vimix-cursors, Vimix-hyprcursor)
├── .zshrc                    # Copy to ~/.zshrc
├── zen/
│   ├── profile/              # Copy into your Zen profile (user.js, chrome/userChrome.css)
│   └── opt/                  # Copy into /opt/zen-browser-bin/ with sudo (live colours, optional)
├── cursor-src/               # Cursor hotspot tools and notes (not installed)
├── packages.txt              # Suggested packages: what the config needs (official + AUR)
└── README.md
```

---

## 🙏 Credits & Inspirations

*   [binnewbs](https://github.com/binnewbs) and [JaKooLit](https://github.com/JaKooLit): the starting point of this configuration and the idea of wallpaper-based theming with Matugen.
*   Ajmashell: [serpantinum](https://github.com/ilyamiro/serpantinum), [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell), [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland), [caelestia-dots/shell](https://github.com/caelestia-dots/shell), [omarchy](https://github.com/basecamp/omarchy) — details in [`SOURCES.md`](.config/quickshell/ajmashell/SOURCES.md).
