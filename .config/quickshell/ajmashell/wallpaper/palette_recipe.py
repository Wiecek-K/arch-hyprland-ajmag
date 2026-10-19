#!/usr/bin/env python3
# Przepis palety (faza E): the one set of matugen parameters the system uses for every wallpaper, read from
# ~/.config/matugen/przepis-palety.json and turned into matugen flags. indexer.py imports it, wpapply.sh calls it from
# the command line, so neither keeps its own copy of the flags (ADR 0019). Own implementation, Python standard
# library only. A missing or broken file, or a bad field, never raises: that field takes its starting value (today's
# flags) and a warning goes to stderr, so changing the wallpaper always works.
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Usage: palette_recipe.py [--file PATH] flags palette   one matugen flag per line (none for the starting values)
#        palette_recipe.py [--file PATH] fingerprint     short hash of the validated recipe
# Tests: ~/Projects/hyprland-lua-migration/tools/test-palette-recipe.py

import hashlib
import json
import math
import os
import sys

DEFAULT_PATH = os.path.expanduser("~/.config/matugen/przepis-palety.json")
SCHEMES = {"scheme-tonal-spot", "scheme-vibrant", "scheme-expressive", "scheme-content", "scheme-fidelity",
           "scheme-monochrome", "scheme-neutral", "scheme-rainbow", "scheme-fruit-salad", "scheme-smart"}
# Starting values = matugen 4.2.0 defaults, which wpapply.sh and indexer.py used before faza E
DEFAULTS = {"palette": {"scheme": "scheme-tonal-spot", "contrast": 0.0, "lightnessDark": 0.0}}


def _number(lo, hi):
    def check(v):
        if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v) or not lo <= v <= hi:
            return None
        return float(v)
    return check


# field: (validator returning the normalised value or None, description for the warning)
PALETTE_FIELDS = {
    "scheme": (lambda v: v if v in SCHEMES else None, "one of " + ", ".join(sorted(SCHEMES))),
    "contrast": (_number(-1.0, 1.0), "a number from -1 to 1"),
    "lightnessDark": (_number(-math.inf, 1.0), "a number up to 1"),
}


def _warn(path, msg):
    print(f"palette_recipe: {path}: {msg}; using the starting value", file=sys.stderr)


def load(path=None):
    """The validated recipe from the file; never raises."""
    path = path or DEFAULT_PATH
    recipe = {"palette": dict(DEFAULTS["palette"])}
    try:
        with open(path) as f:
            data = json.load(f)
    except OSError as e:
        _warn(path, f"cannot read ({e.strerror})")
        return recipe
    except ValueError as e:
        _warn(path, f"not valid JSON ({e})")
        return recipe
    if not isinstance(data, dict):
        _warn(path, "not a JSON object")
        return recipe
    for key in data.keys() - DEFAULTS.keys():
        print(f"palette_recipe: {path}: unknown field {key!r} ignored", file=sys.stderr)
    palette = data.get("palette", {})
    if not isinstance(palette, dict):
        _warn(path, "palette is not a JSON object")
        return recipe
    for key in palette.keys() - PALETTE_FIELDS.keys():
        print(f"palette_recipe: {path}: unknown field palette.{key!r} ignored", file=sys.stderr)
    for key, (check, want) in PALETTE_FIELDS.items():
        if key not in palette:
            continue
        value = check(palette[key])
        if value is None:
            _warn(path, f"palette.{key} = {json.dumps(palette[key])} is not {want}")
        else:
            recipe["palette"][key] = value
    return recipe


def palette_flags(recipe):
    """Flags for building the palette from the Seed (`matugen image` and `matugen color hex`): only values other than
    matugen's defaults, so the starting recipe gives exactly the commands used before faza E. --flag=value, because a
    negative value after a space would be read as an option."""
    p, d = recipe["palette"], DEFAULTS["palette"]
    flags = []
    if p["scheme"] != d["scheme"]:
        flags += ["-t", p["scheme"]]
    if p["contrast"] != d["contrast"]:
        flags.append(f"--contrast={p['contrast']}")
    if p["lightnessDark"] != d["lightnessDark"]:
        flags.append(f"--lightness-dark={p['lightnessDark']}")
    return flags


def fingerprint(recipe):
    """Hash of the validated recipe: the file's formatting and key order do not change it."""
    canon = json.dumps(recipe, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canon.encode()).hexdigest()[:16]


def main(argv):
    path = None
    if argv[:1] == ["--file"] and len(argv) > 1:
        path, argv = argv[1], argv[2:]
    if argv == ["flags", "palette"]:
        out = palette_flags(load(path))
    elif argv == ["fingerprint"]:
        out = [fingerprint(load(path))]
    else:
        print("usage: palette_recipe.py [--file PATH] flags palette | fingerprint", file=sys.stderr)
        return 2
    sys.stdout.write("".join(line + "\n" for line in out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
