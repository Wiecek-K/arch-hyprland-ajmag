#!/usr/bin/env python3
# Extras of Ajmashell (Theme Center 1.0.next ticket tc05): the switches in the live file
# ~/.local/state/ajmashell/extras.json, which Theme Center's Fun tab writes and Extras.qml watches. The list of extras
# comes from extras-options.json next to this file, never copied. Theme Center's helper imports this module from the
# Ajmashell directory. Own implementation, Python standard library only; same pattern as look_settings.py (lenient
# load, strict atomic save).
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# load() never raises: no file = every extra off; a broken file, or a bad field, gives off for that part and a warning on
# stderr. Extras.qml reads the file the same way (extras.mjs).
# Tests: ~/Projects/hyprland-lua-migration/tools/test-extras-settings.py

import contextlib
import json
import os
import secrets
import sys

DEFAULT_PATH = os.path.expanduser("~/.local/state/ajmashell/extras.json")
OPTIONS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "extras-options.json")


def options():
    """extras-options.json without its comment: {"extras": [{name, title, description}]}."""
    with open(OPTIONS_PATH, encoding="utf-8") as f:
        data = json.load(f)
    data.pop("_comment", None)
    return data


def _warn(path, msg):
    print(f"extras_settings: {path}: {msg}", file=sys.stderr)


def load(path=None):
    """{name: bool} of every extra, as the file says; never raises."""
    path = path or DEFAULT_PATH
    out = {e["name"]: False for e in options()["extras"]}
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        return out
    except OSError as e:
        _warn(path, f"cannot read ({e.strerror}); every extra off")
        return out
    except ValueError as e:
        _warn(path, f"not valid JSON ({e}); every extra off")
        return out
    if not isinstance(data, dict):
        _warn(path, "not a JSON object; every extra off")
        return out
    for key in data:
        if key not in out:
            _warn(path, f"unknown field {key!r} ignored")
    for name in out:
        if name not in data:
            continue
        if isinstance(data[name], bool):
            out[name] = data[name]
        else:
            _warn(path, f"{name} = {json.dumps(data[name])} is not true or false; off")
    return out


def save(extras, path=None):
    """Write the switches in the format load() reads. Strict, unlike load(): exactly every extra of extras-options.json,
    each true or false, else ValueError and the file stays as it was. Atomic (a temporary file next to it, then one
    rename; a symlink keeps pointing at its replaced target); creates the directory. Returns the validated switches."""
    path = path or DEFAULT_PATH
    names = [e["name"] for e in options()["extras"]]
    if not isinstance(extras, dict) or extras.keys() != set(names):
        raise ValueError(f"extras_settings: the switches need exactly the fields {', '.join(names)}")
    for name in names:
        if not isinstance(extras[name], bool):
            raise ValueError(f"extras_settings: {name} = {json.dumps(extras[name])} is not true or false")
    valid = {name: extras[name] for name in names}
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
