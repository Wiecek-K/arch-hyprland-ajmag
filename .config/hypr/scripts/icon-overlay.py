#!/usr/bin/env python3
# Folder icons in the wallpaper colour (ticket 46, faza B). matugen post_hook ([templates.icon_accent] in
# ~/.config/matugen/config.toml), started in the background with `setsid -f`.
# Builds a small icon theme in ~/.local/share/icons that inherits Colloid-Teal-Dark and holds only the places/ icons
# with Colloid's Teal accent #4DB6AC, recoloured to matugen's primary (written by the template to ACCENT_FILE).
# A running GTK app reloads icons only when the theme name changes, so there are two copies, Ajmashell-Dark-a and -b:
# each run rebuilds the one not in use and switches gsettings to it. Ajmashell-Dark is a symlink to the newest copy
# for settings.ini and the Ajmashell pragma (read at start only).
# Usage: icon-overlay.py [#rrggbb]   (default: the colour in ACCENT_FILE)
import sys

sys.dont_write_bytecode = True  # imported by tools/test-icon-overlay.py
import fcntl
import os
import re
import shutil
import subprocess

PARENT = "/usr/share/icons/Colloid-Teal-Dark"
ACCENT = "#4DB6AC"
NAME = "Ajmashell-Dark"
ICONS = os.path.expanduser("~/.local/share/icons")
ACCENT_FILE = os.path.expanduser("~/.cache/ajmashell/icon-accent.txt")
PLACES = "places/scalable"
SMALL = ("16", "22", "24")  # Colloid's line icons for small sizes: same names, no accent


def recolor(svg, color):
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", color):
        raise ValueError(f"not a #rrggbb colour: {color!r}")
    return re.sub(re.escape(ACCENT), color, svg, flags=re.IGNORECASE)


def accent_icons(parent):
    """(files with the accent, {link: its target} for links that resolve to one of them) in places/scalable."""
    d = os.path.join(parent, PLACES)
    files = []
    for name in sorted(os.listdir(d)):
        path = os.path.join(d, name)
        if name.endswith(".svg") and not os.path.islink(path):
            with open(path, errors="replace") as f:
                if ACCENT.lower() in f.read().lower():
                    files.append(name)
    links = {}
    for name in sorted(os.listdir(d)):
        path = os.path.join(d, name)
        if os.path.islink(path):
            target = os.path.realpath(path)
            if os.path.dirname(target) == os.path.realpath(d) and os.path.basename(target) in files:
                links[name] = os.readlink(path)
    return files, links


def _sections(index_text):
    """{section name: its lines} of an index.theme."""
    sections, current = {}, None
    for line in index_text.splitlines():
        m = re.fullmatch(r"\[(.+)\]", line.strip())
        if m:
            current = sections.setdefault(m.group(1), [])
        elif current is not None and line.strip() and not line.startswith("#"):
            current.append(line.strip())
    return sections


def index_theme(name, parent_name, parent_index):
    """index.theme of the overlay: the parent's places/ directories except symbolic, inheriting the parent."""
    sections = _sections(parent_index)
    head = dict(line.split("=", 1) for line in sections["Icon Theme"] if "=" in line)

    def keep(key):
        return [d for d in head.get(key, "").split(",") if re.fullmatch(r"places(@2x)?/(scalable|\d+)", d)]

    dirs, scaled = keep("Directories"), keep("ScaledDirectories")
    out = ["[Icon Theme]", f"Name={name}", f"Comment={parent_name} with folders in the wallpaper colour (Ajmashell)",
           f"Inherits={parent_name}", "Example=folder", f"Directories={','.join(dirs)}",
           f"ScaledDirectories={','.join(scaled)}", ""]
    for d in dirs + scaled:
        out += [f"[{d}]", *sections[d], ""]
    return "\n".join(out)


def build(parent, out, color):
    """Write the overlay theme to out (replacing it)."""
    files, links = accent_icons(parent)
    shutil.rmtree(out, ignore_errors=True)
    scalable = os.path.join(out, PLACES)
    os.makedirs(scalable)
    for name in files:
        with open(os.path.join(parent, PLACES, name), errors="replace") as f:
            svg = recolor(f.read(), color)
        with open(os.path.join(scalable, name), "w") as f:
            f.write(svg)
    for name, target in links.items():
        os.symlink(target, os.path.join(scalable, name))
    # GTK takes an icon from the first theme that has the name at any size: keep the parent's small icons in front
    for size in SMALL:
        for name in files + list(links):
            src = os.path.join(parent, "places", size, name)
            if os.path.exists(src):
                os.makedirs(os.path.join(out, "places", size), exist_ok=True)
                os.symlink(os.path.realpath(src), os.path.join(out, "places", size, name))
    os.symlink("places", os.path.join(out, "places@2x"))
    with open(os.path.join(parent, "index.theme")) as f:
        text = index_theme(os.path.basename(out), os.path.basename(parent), f.read())
    with open(os.path.join(out, "index.theme"), "w") as f:
        f.write(text)


def next_slot(current):
    return f"{NAME}-b" if current == f"{NAME}-a" else f"{NAME}-a"


def main():
    if len(sys.argv) > 1:
        color = sys.argv[1]
    else:
        with open(ACCENT_FILE) as f:
            color = f.read().strip()
    os.makedirs(ICONS, exist_ok=True)
    # quick wallpaper changes start several hooks: one at a time, the last one wins
    lock = open(os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "icon-overlay.lock"), "w")
    fcntl.flock(lock, fcntl.LOCK_EX)
    key = ["org.gnome.desktop.interface", "icon-theme"]
    current = subprocess.run(["gsettings", "get", *key], capture_output=True, text=True).stdout.strip().strip("'")
    slot = next_slot(current)
    build(PARENT, os.path.join(ICONS, slot), color)
    tmp = os.path.join(ICONS, f".{NAME}.new")
    if os.path.lexists(tmp):
        os.remove(tmp)
    os.symlink(slot, tmp)
    os.replace(tmp, os.path.join(ICONS, NAME))
    subprocess.run(["gsettings", "set", *key, slot], check=True)


if __name__ == "__main__":
    main()
