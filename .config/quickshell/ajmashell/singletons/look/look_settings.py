#!/usr/bin/env python3
# Look of Ajmashell's big popups (faza E ticket 13, ADR 0021): the parameters in the live file
# ~/.local/state/ajmashell/look.json, which Theme Center writes and Look.qml watches. Roles, ranges, presets and the
# defaults come from look-options.json next to this file, never copied. Theme Center's helper imports this module from
# the Ajmashell directory. Own implementation, Python standard library only; same pattern as
# wallpaper/palette_recipe.py (lenient load, strict atomic save).
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# load() never raises: no file = the defaults; a broken file, or a bad field, gives the defaults for that part and a
# warning on stderr. Look.qml reads the file the same way (look.mjs).
# Tests: ~/Projects/hyprland-lua-migration/tools/test-look-settings.py

import contextlib
import json
import math
import os
import secrets
import sys

DEFAULT_PATH = os.path.expanduser("~/.local/state/ajmashell/look.json")
OPTIONS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "look-options.json")


def options():
    """look-options.json without its comment: roles, alpha {min, max, step}, flags, presets, defaults."""
    with open(OPTIONS_PATH, encoding="utf-8") as f:
        data = json.load(f)
    data.pop("_comment", None)
    return data


def _fields(opts):
    """{field: (validator returning the normalised value or None, description for a message)} in file order."""
    lo, hi = opts["alpha"]["min"], opts["alpha"]["max"]

    def role(v):
        return v if isinstance(v, str) and v in opts["roles"] else None

    def alpha(v):
        if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v) or not lo <= v <= hi:
            return None
        return float(v)

    def flag(v):
        return v if isinstance(v, bool) else None

    fields = {"background": (role, "a role of look-options.json"), "alpha": (alpha, f"a number from {lo} to {hi}")}
    fields.update({name: (flag, "true or false") for name in opts["flags"]})
    return fields


def _warn(path, msg):
    print(f"look_settings: {path}: {msg}", file=sys.stderr)


def load(path=None):
    """The look in the file, every field valid; never raises."""
    path = path or DEFAULT_PATH
    opts = options()
    fields = _fields(opts)
    look = {k: fields[k][0](opts["defaults"][k]) for k in fields}
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        return look
    except OSError as e:
        _warn(path, f"cannot read ({e.strerror}); using the defaults")
        return look
    except ValueError as e:
        _warn(path, f"not valid JSON ({e}); using the defaults")
        return look
    if not isinstance(data, dict):
        _warn(path, "not a JSON object; using the defaults")
        return look
    for key in data.keys() - fields.keys():
        _warn(path, f"unknown field {key!r} ignored")
    for key, (check, want) in fields.items():
        if key not in data:
            continue
        value = check(data[key])
        if value is None:
            _warn(path, f"{key} = {json.dumps(data[key])} is not {want}; using the default")
        else:
            look[key] = value
    return look


def save(look, path=None):
    """Write the look in the format load() reads. Strict, unlike load(): exactly every field, each valid, else
    ValueError and the file stays as it was. Atomic (a temporary file next to it, then one rename); creates the
    directory. Returns the validated look."""
    path = path or DEFAULT_PATH
    fields = _fields(options())
    if not isinstance(look, dict) or look.keys() != fields.keys():
        raise ValueError(f"look_settings: the look needs exactly the fields {', '.join(fields)}")
    valid = {}
    for key, (check, want) in fields.items():
        value = check(look[key])
        if value is None:
            raise ValueError(f"look_settings: {key} = {json.dumps(look[key])} is not {want}")
        valid[key] = value
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
