#!/usr/bin/env python3
# Przepis palety (faza E): the one set of matugen parameters the system uses for every wallpaper, read from
# ~/.config/matugen/przepis-palety.json and turned into matugen flags. indexer.py imports it, wpapply.sh calls it from
# the command line, so neither keeps its own copy of the flags (ADR 0019). Own implementation, Python standard
# library only. A missing or broken file, or a bad field, never raises: that field takes its starting value (today's
# flags) and a warning goes to stderr, so changing the wallpaper always works.
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Two parts: "seed" (which Kandydat becomes the Seed, one rule for every wallpaper; ticket 03) and "palette" (how
# the palette is built from the Seed; ticket 02). save() writes the file atomically for a user interface that edits
# the recipe, so it keeps no format of its own (ticket 07).
#
# Usage: palette_recipe.py [--file PATH] flags seed      Seed-choice flags for `matugen image`, one per line
#        palette_recipe.py [--file PATH] flags palette   palette flags, one per line (none for the starting values)
#        palette_recipe.py [--file PATH] fingerprint     short hash of the validated recipe
# Tests: ~/Projects/hyprland-lua-migration/tools/test-palette-recipe.py

import contextlib
import hashlib
import json
import math
import os
import sys
import tempfile

DEFAULT_PATH = os.path.expanduser("~/.config/matugen/przepis-palety.json")
# Tuples: options() lists them in this order for a user interface (starting value first).
SCHEMES = ("scheme-tonal-spot", "scheme-vibrant", "scheme-expressive", "scheme-content", "scheme-fidelity",
           "scheme-monochrome", "scheme-neutral", "scheme-rainbow", "scheme-fruit-salad", "scheme-smart")
# dominant = the most dominant Kandydat (--source-color-index 0); the others are matugen's --prefer rules.
# Not rules (ADR 0019, decision 2): a fixed Kandydat position (gives a random background colour on most wallpapers)
# and closest-to-fallback (needs a fixed colour).
SEED_RULES = ("dominant", "darkness", "lightness", "saturation", "less-saturation", "value")
# Accepted ranges of matugen 4.2.0 (`matugen --help`)
RANGES = {"contrast": (-1.0, 1.0), "lightnessDark": (-math.inf, 1.0)}
# Starting values = the flags wpapply.sh and indexer.py used before faza E (matugen 4.2.0 defaults for the palette)
DEFAULTS = {"seed": {"rule": "dominant"},
            "palette": {"scheme": "scheme-tonal-spot", "contrast": 0.0, "lightnessDark": 0.0}}


def _number(lo, hi):
    def check(v):
        if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v) or not lo <= v <= hi:
            return None
        return float(v)
    return check


def _one_of(names):
    return lambda v: v if isinstance(v, str) and v in names else None


# section: {field: (validator returning the normalised value or None, description for the warning)}
FIELDS = {
    "seed": {
        "rule": (_one_of(SEED_RULES), "one of " + ", ".join(sorted(SEED_RULES))
                 + " (a Kandydat position and closest-to-fallback are not rules)"),
    },
    "palette": {
        "scheme": (_one_of(SCHEMES), "one of " + ", ".join(sorted(SCHEMES))),
        "contrast": (_number(*RANGES["contrast"]), "a number from {} to {}".format(*RANGES["contrast"])),
        "lightnessDark": (_number(*RANGES["lightnessDark"]), "a number up to {}".format(RANGES["lightnessDark"][1])),
    },
}


def _warn(path, msg):
    print(f"palette_recipe: {path}: {msg}; using the starting value", file=sys.stderr)


def load(path=None):
    """The validated recipe from the file; never raises."""
    path = path or DEFAULT_PATH
    recipe = {section: dict(values) for section, values in DEFAULTS.items()}
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
    for section, fields in FIELDS.items():
        given = data.get(section, {})
        if not isinstance(given, dict):
            _warn(path, f"{section} is not a JSON object")
            continue
        for key in given.keys() - fields.keys():
            print(f"palette_recipe: {path}: unknown field {section}.{key!r} ignored", file=sys.stderr)
        for key, (check, want) in fields.items():
            if key not in given:
                continue
            value = check(given[key])
            if value is None:
                _warn(path, f"{section}.{key} = {json.dumps(given[key])} is not {want}")
            else:
                recipe[section][key] = value
    return recipe


def _umask():
    mask = os.umask(0)
    os.umask(mask)
    return mask


def save(recipe, path=None):
    """Write the recipe to the file in the format load() reads. Unlike load() it is strict: every field must be given
    and valid, else ValueError and the file stays as it was (a user interface must not save starting values it did
    not show). Returns the validated recipe."""
    path = path or DEFAULT_PATH
    if not isinstance(recipe, dict) or recipe.keys() != FIELDS.keys():
        raise ValueError(f"palette_recipe: the recipe needs exactly the sections {', '.join(FIELDS)}")
    valid = {}
    for section, fields in FIELDS.items():
        given = recipe[section]
        if not isinstance(given, dict) or given.keys() != fields.keys():
            raise ValueError(f"palette_recipe: {section} needs exactly the fields {', '.join(fields)}")
        valid[section] = {}
        for key, (check, want) in fields.items():
            value = check(given[key])
            if value is None:
                raise ValueError(f"palette_recipe: {section}.{key} = {json.dumps(given[key])} is not {want}")
            valid[section][key] = value
    # a temporary file next to it, then one rename: a reader gets the old file or the new one, never half of it.
    # Through a symlink (dotfiles linked into ~/.config) the target is replaced and the link stays; the permissions
    # stay those of the old file (mkstemp gives 0600), or the umask's for a new one.
    path = os.path.realpath(path)
    try:
        mode = os.stat(path).st_mode & 0o7777
    except FileNotFoundError:
        mode = 0o666 & ~_umask()
    fd, tmp = tempfile.mkstemp(prefix="." + os.path.basename(path) + ".", dir=os.path.dirname(path))
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "w") as f:
            f.write(json.dumps(valid, indent=2) + "\n")
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except BaseException:
        with contextlib.suppress(OSError):
            os.unlink(tmp)
        raise
    return valid


def options():
    """The values the recipe accepts, for a user interface that edits it (so it keeps no copy): rules and schemes in
    order, number ranges as [low, high] with None for no limit (JSON has no infinity)."""
    def finite_or_none(v):
        return None if math.isinf(v) else v
    return {"rules": list(SEED_RULES), "schemes": list(SCHEMES),
            **{k: [finite_or_none(lo), finite_or_none(hi)] for k, (lo, hi) in RANGES.items()}}


def seed_flags(recipe):
    """Flags for choosing the Seed among the Kandydaci (`matugen image` only): always exactly one rule. With both
    --source-color-index and --prefer matugen 4.2.0 takes the index; with neither it asks interactively."""
    rule = recipe["seed"]["rule"]
    return ["--source-color-index", "0"] if rule == "dominant" else ["--prefer", rule]


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
    if argv == ["flags", "seed"]:
        out = seed_flags(load(path))
    elif argv == ["flags", "palette"]:
        out = palette_flags(load(path))
    elif argv == ["fingerprint"]:
        out = [fingerprint(load(path))]
    else:
        print("usage: palette_recipe.py [--file PATH] flags seed | flags palette | fingerprint", file=sys.stderr)
        return 2
    sys.stdout.write("".join(line + "\n" for line in out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
