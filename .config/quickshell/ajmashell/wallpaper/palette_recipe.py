#!/usr/bin/env python3
# Palette recipe (faza E): the one set of matugen parameters the system uses for every wallpaper, turned into matugen
# flags. indexer.py imports it, wpapply.sh calls it from the command line, so neither keeps its own copy of the flags
# (ADR 0019). Own implementation, Python standard library only.
#
# Two files (ticket 15, the model of ADR 0021): the live file ~/.local/state/ajmashell/palette-recipe.json, outside
# git, which Theme Center writes; and the default recipe palette-recipe-default.json next to this module. No live file
# = the default recipe. A bad field of the live file takes the default recipe's value; a missing or broken default
# recipe, or a bad field of it, takes the starting value (DEFAULTS). Each with a warning on stderr, never an exception,
# so changing the wallpaper always works.
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Two parts: "seed" (which candidate becomes the seed, one rule for every wallpaper; ticket 03) and "palette" (how
# the palette is built from the seed; ticket 02). save() writes the file atomically for a user interface that edits
# the recipe, so it keeps no format of its own (ticket 07).
#
# Usage: palette_recipe.py [--file PATH] flags seed      seed-choice flags for `matugen image`, one per line
#        palette_recipe.py [--file PATH] flags palette   palette flags, one per line (none for the starting values)
#        palette_recipe.py [--file PATH] fingerprint     short hash of the validated recipe
# Tests: ~/Projects/hyprland-lua-migration/tools/test-palette-recipe.py

import contextlib
import hashlib
import json
import math
import os
import secrets
import sys

DEFAULT_PATH = os.path.expanduser("~/.local/state/ajmashell/palette-recipe.json")  # the live file
DEFAULT_RECIPE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "palette-recipe-default.json")
# Tuples: options() lists them in this order for a user interface (starting value first).
SCHEMES = ("scheme-tonal-spot", "scheme-vibrant", "scheme-expressive", "scheme-content", "scheme-fidelity",
           "scheme-monochrome", "scheme-neutral", "scheme-rainbow", "scheme-fruit-salad", "scheme-smart")
# dominant = the most dominant candidate (--source-color-index 0); the others are matugen's --prefer rules.
# Not rules (ADR 0019, decision 2): a fixed candidate position (gives a random background colour on most wallpapers)
# and closest-to-fallback (needs a fixed colour).
SEED_RULES = ("dominant", "darkness", "lightness", "saturation", "less-saturation", "value")
# Accepted ranges of matugen 4.2.0 (`matugen --help`)
RANGES = {"contrast": (-1.0, 1.0), "lightnessDark": (-math.inf, 1.0)}
# Starting values = the flags wpapply.sh and indexer.py used before faza E (matugen 4.2.0 defaults for the palette);
# only for a damaged default recipe
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
                 + " (a candidate position and closest-to-fallback are not rules)"),
    },
    "palette": {
        "scheme": (_one_of(SCHEMES), "one of " + ", ".join(sorted(SCHEMES))),
        "contrast": (_number(*RANGES["contrast"]), "a number from {} to {}".format(*RANGES["contrast"])),
        "lightnessDark": (_number(*RANGES["lightnessDark"]), "a number up to {}".format(RANGES["lightnessDark"][1])),
    },
}


def _invalid(section, key, value, want):
    return f"{section}.{key} = {json.dumps(value)} is not {want}"


def _note(warnings, line):
    if warnings is None:
        print(line, file=sys.stderr)
    else:
        warnings.append(line)


def load(path=None, default=None, warnings=None):
    """The validated recipe: the live file over the default recipe; never raises. Warnings go to stderr, or into the
    list `warnings` when given (Theme Center shows them in its window)."""
    base = _layer({section: dict(values) for section, values in DEFAULTS.items()},
                  default or DEFAULT_RECIPE_PATH, "the starting value", False, warnings)
    return _layer(base, path or DEFAULT_PATH, "the default recipe's value", True, warnings)


def _layer(base, path, fallback, missing_ok, warnings):
    """The valid fields of the file over a copy of base; a warning for every other one."""
    recipe = {section: dict(values) for section, values in base.items()}

    def warn(msg):
        _note(warnings, f"palette_recipe: {path}: {msg}; using {fallback}")

    try:
        with open(path) as f:
            data = json.load(f)
    except FileNotFoundError as e:
        if not missing_ok:
            warn(f"cannot read ({e.strerror})")
        return recipe
    except OSError as e:
        warn(f"cannot read ({e.strerror})")
        return recipe
    except ValueError as e:
        warn(f"not valid JSON ({e})")
        return recipe
    if not isinstance(data, dict):
        warn("not a JSON object")
        return recipe
    for key in data.keys() - DEFAULTS.keys():
        _note(warnings, f"palette_recipe: {path}: unknown field {key!r} ignored")
    for section, fields in FIELDS.items():
        given = data.get(section, {})
        if not isinstance(given, dict):
            warn(f"{section} is not a JSON object")
            continue
        for key in given.keys() - fields.keys():
            _note(warnings, f"palette_recipe: {path}: unknown field {section}.{key!r} ignored")
        for key, (check, want) in fields.items():
            if key not in given:
                continue
            value = check(given[key])
            if value is None:
                warn(_invalid(section, key, given[key], want))
            else:
                recipe[section][key] = value
    return recipe


def save(recipe, path=None):
    """Write the recipe to the file in the format load() reads. Unlike load() it is strict: every field must be given
    and valid, else ValueError and the file stays as it was (a user interface must not save starting values it did
    not show). Creates the directory. Returns the validated recipe."""
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
                raise ValueError("palette_recipe: " + _invalid(section, key, given[key], want))
            valid[section][key] = value
    # a temporary file next to it, then one rename: a reader gets the old file or the new one, never half of it.
    # Through a symlink (dotfiles linked into ~/.config) the target is replaced and the link stays; the permissions
    # stay those of the old file, or the umask's for a new one (os.open applies it; reading it with os.umask() would
    # change it for a moment in every thread of a caller).
    path = os.path.realpath(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = os.path.join(os.path.dirname(path), f".{os.path.basename(path)}.{secrets.token_hex(4)}")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o666)
    try:
        with contextlib.suppress(FileNotFoundError):
            os.fchmod(fd, os.stat(path).st_mode & 0o7777)
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
    """Flags for choosing the seed among the candidates (`matugen image` only): always exactly one rule. With both
    --source-color-index and --prefer matugen 4.2.0 takes the index; with neither it asks interactively."""
    rule = recipe["seed"]["rule"]
    return ["--source-color-index", "0"] if rule == "dominant" else ["--prefer", rule]


def palette_flags(recipe):
    """Flags for building the palette from the seed (`matugen image` and `matugen color hex`): only values other than
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
