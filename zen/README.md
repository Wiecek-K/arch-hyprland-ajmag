# Zen Browser

Matugen colours, a semi-transparent window and an edge-to-edge page in compact mode for [Zen Browser](https://zen-browser.app/).
Everything here is optional: without it Zen keeps its own look.

| Path | Goes to | What it does |
|---|---|---|
| `profile/chrome/userChrome.css` | `<profile>/chrome/` | Matugen colours, transparent window and sidebars, compact mode without the frame around the page |
| `profile/user.js` | `<profile>/` | Turns on `userChrome.css` and the transparent window |
| `opt/config.js`, `opt/defaults/pref/autoconfig.js` | `/opt/zen-browser-bin/` (root) | Live colours: reload after each wallpaper change, no browser restart |

## 1. Profile

Start Zen once first, so it creates its profile (the `Default=` line of `~/.config/zen/installs.ini`).
Then run from the root of this repository:

```bash
PROFILE=~/.config/zen/"$(sed -n 's/^Default=//p' ~/.config/zen/installs.ini 2>/dev/null | head -n 1)"
if [ "$PROFILE" != ~/.config/zen/ ] && [ -d "$PROFILE" ]; then
    cp -r --backup=numbered zen/profile/. "$PROFILE/"
    rm -rf ~/.local/state/ajmashell/zen-chrome && ln -s "$PROFILE/chrome" ~/.local/state/ajmashell/zen-chrome
else
    echo "No Zen profile: start Zen once, then run these lines again"
fi
```

The link is where Matugen writes Zen's colours (`matugen-colors.css`, `[templates.zen]` in `.config/matugen/config.toml`).
`userChrome.css` imports that file. Firefox reads both only at startup, so restart Zen after copying.

## 2. Live colours (optional, needs sudo)

```bash
sudo cp -r zen/opt/. /opt/zen-browser-bin/
```

The AutoConfig script `config.js` re-registers `matugen-colors.css` as a user style sheet each time Matugen's post_hook
connects to its Unix socket (`$XDG_RUNTIME_DIR/ajmashell-zen.sock`, via `socat`) after a wallpaper change.
No browser restart, no polling. The script lives in root-owned `/opt`, not in the profile, because any user process can
write the profile. Skip this step and the colours change on the next Zen start.

Roll back: `sudo rm /opt/zen-browser-bin/config.js /opt/zen-browser-bin/defaults/pref/autoconfig.js`, restart Zen.
Log: Browser Console (`Ctrl+Shift+J`), filter `ajmashell-zen`.

## 3. Transparent window

No mod needed. `user.js` sets the two prefs that let Zen draw a transparent window:

| Pref | Default | Why |
|---|---|---|
| `zen.widget.linux.transparency` | `false` | Zen's switch for a transparent window on Linux (Zen 1.11.2b and newer) |
| `browser.tabs.allow_transparent_browser` | `false` | Lets the tab area be transparent too |

Check them in `about:config`. On Windows 11 the matching prefs are `widget.transparent-windows` and `widget.windows.mica`
(not used by this config, which targets Linux).

`userChrome.css` then paints the window background (also the frame around the page) and the pinned sidebar with one
layer of the Matugen surface at 50 % opacity. The desktop behind it is blurred by Hyprland, not by Zen:
`decoration.blur` in `.config/hypr/configs/looknfeel.lua` (global for all windows; Hyprland has no per-window blur strength).

The compact (auto-hide) sidebar is a separate floating panel over the page. It gets the surface at 75 % plus Zen's own
CSS blur (`backdrop-filter: blur(42px)`, the value of Zen's acrylic sidebar), so page text under it does not mix with
tab names. A CSS blur sees only what Zen draws, never the desktop.

In compact mode the page fills the whole window: no frame, rounded corners or shadow around it.

## Tuning

Variables at the top of `userChrome.css` (restart Zen after an edit):

| Variable | Default | What |
|---|---|---|
| `--ajm-window-bg` | surface 50 % | window background and pinned sidebar |
| `--ajm-compact-bg` | surface 75 % | compact sidebar panel |
| `--ajm-compact-blur` | `blur(42px)` | blur of the page under the compact sidebar |

Do not give `#navigator-toolbox`, `--toolbar-bgcolor` or `--lwt-sidebar-background-color` an opaque colour with
`!important`: that covers the transparent window, and the sidebar turns solid again.
