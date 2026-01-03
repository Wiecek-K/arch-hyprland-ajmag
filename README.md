Jasne, to bardzo ważny gest w społeczności Open Source. Zaktualizowałem sekcję nagłówkową w `README.md`, dodając wyraźne podziękowania dla obu twórców.

Oto ostateczna wersja pliku. Podmień zawartość `~/arch-hyprland-ajmag/README.md` na poniższą:

```markdown
# Arch Linux + Hyprland (AJMAG Configuration)

![Arch Linux](https://img.shields.io/badge/Arch_Linux-DISTRO-1793d1?style=for-the-badge&logo=arch-linux)
![Hyprland](https://img.shields.io/badge/Hyprland-WM-00a4a6?style=for-the-badge&logo=hyprland)
![Matugen](https://img.shields.io/badge/Matugen-THEMING-ff0055?style=for-the-badge)

A highly customized, stable, and performance-oriented Hyprland environment.
This configuration prioritizes **text clarity** ("High Visibility Mode") and **dynamic theming**, while providing robust support for **Hybrid Graphics (Intel/Nvidia)** laptops.

> **Credits:** This configuration is heavily based on the excellent work of [binnewbs](https://github.com/binnewbs) and [JaKooLit](https://github.com/JaKooLit).

---

## 🌟 Key Features

### 🎨 Visual Identity
*   **Dynamic Theming:** System-wide colors generated from your wallpaper using `Matugen`.
    *   *Affected apps:* Waybar, Kitty, Rofi, Hyprland borders, Zen Browser (via userChrome.css).
*   **Typography:** Global usage of **Atkinson Hyperlegible** (UI) and **Atkinson Hyperlegible Mono** (Terminal/Code) for maximum readability.
*   **High Visibility Mode:**
    *   **Active Windows:** 100% opacity + colored border (3px).
    *   **Text-Heavy Apps:** (Browsers, IDEs, Discord) maintain 95-100% opacity even when inactive to prevent eye strain.
    *   **Background Apps:** (File managers, settings) fade to 80% opacity when inactive.

### ⚙️ System & Hardware
*   **Hybrid Graphics Support:** Optimized for Pascal architecture (GTX 1050).
    *   Includes custom `udev` rules to create stable symlinks (`/dev/dri/intel-card`, `/dev/dri/nvidia-card`), preventing Hyprland crashes on boot.
*   **Performance:**
    *   `preload` daemon enabled for faster app launches.
    *   Bloat-free: Unnecessary services (like `pyprland`) removed.
*   **Monitor Management:**
    *   Custom scripts for hot-plugging displays.
    *   Failsafe mechanism to prevent black screens when disconnecting HDMI.

---

## 📦 Installation

### 1. Clone the Repository
```bash
git clone https://github.com/YOUR_USERNAME/arch-hyprland-ajmag.git
cd arch-hyprland-ajmag
```

### 2. Run the Installer
The script will install packages (Official & AUR), backup your existing configs, and link the new ones.
```bash
chmod +x install.sh
./install.sh
```
> **Note:** During installation, you will be asked if you want to download the **Wallpaper Pack**. This clones a separate repository to keep this config lightweight.

### 3. Post-Install
1.  **Reboot** your system.
2.  **First Run:** Press `Super + W` to select a wallpaper and generate the initial color scheme.
3.  **Zen Browser:** Restart the browser to apply the generated theme.

---

## 🖥️ Monitor Configuration (Critical)

The file `~/.config/hypr/monitors.conf` contains hardware-specific port names (e.g., `eDP-1`, `HDMI-A-2`). On a new machine, these names will differ.

**If you see a black screen or errors:**
1.  Switch to TTY (`Ctrl+Alt+F3`).
2.  Run: `echo "" > ~/.config/hypr/monitors.conf` (forces auto-detection).
3.  Return to Hyprland (`Ctrl+Alt+F1` or reboot).
4.  Use **`nwg-displays`** (GUI) to configure your layout and save.

**Quick Switcher:**
Use `Super + Shift + P` to open a menu for quick layout changes (Laptop Only, External Only, Mirror, Extend).

---

## ⌨️ Keybinds & Configuration

All keybindings are defined and can be modified in:
> **`~/.config/hypr/configs/keybinds.conf`**

### ⚠️ Important Note on Keyboard Layout
The workspace switching binds in this configuration use specific symbols (e.g., `bracketleft`, `minus`, `equal`) instead of standard numbers.

**Reason:** This setup is tailored for a **custom keyboard layout** where number keys might behave differently.

**Recommendation:** If you are using a standard layout (QWERTY/ANSI/ISO), **you should edit `keybinds.conf` and revert the workspace binds to standard numbers (`1`, `2`, `3`...)** to ensure they work as expected.

---

## 🛠️ Customizations Detail

### Waybar
*   **Config:** `ajmag-waybar`
*   **Style:** Uses a detached `style.css` to protect font settings from Matugen overwrites.
*   **Features:**
    *   **Roman/Arabic Numerals:** Configured for Arabic (1-10).
    *   **Occupied Indicator:** Workspaces with windows have a distinct color (Secondary) vs Empty (Gray) vs Active (Primary).

### Zen Browser
*   Uses `userChrome.css` to import `matugen-colors.css`.
*   **Limitation:** Due to Firefox/Zen architecture, the browser **must be restarted** to pick up new colors after changing the wallpaper.

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
├── .config/                # Dotfiles (Hypr, Waybar, Kitty, etc.)
├── home_files/             # Files for home dir (.zshrc)
├── system/                 # System-level configs (udev rules)
├── install.sh              # Automated installer
├── pkglist_native.txt      # Official Arch packages
└── pkglist_aur.txt         # AUR packages
```
```