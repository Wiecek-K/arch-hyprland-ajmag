// Pure logic of the Keybinds window (ticket 20): rows from `hyprctl binds -j`, search, scrolling.
// Row form after omarchy's bin/omarchy-menu-keybindings (B11 #07; idea only, own code):
// https://github.com/basecamp/omarchy/blob/fd961e5/bin/omarchy-menu-keybindings
// `SUPER SHIFT + RETURN   → description`: modifiers as words in a fixed order, chord padded to one column
// (the font is monospace), chords with the same description joined with " / ".
// Changes: chords padded to the longest one (not a fixed 35), config order (no priority table), no running of
// the bind (read-only list, user 2026-10-09), key names from a table (no xkbcli).
// Tests: node --test ~/Projects/hyprland-lua-migration/tools/test-keybinds.mjs
// No spread, flatMap or forEach filling objects: Qt's JS engine (see ~/.config/CLAUDE.md).

// Hyprland modmask bits, in the order they are shown
const MODIFIERS = [[64, "SUPER"], [1, "SHIFT"], [4, "CTRL"], [8, "ALT"]];

const KEYS = {
    bracketleft: "[",
    bracketright: "]",
    backslash: "\\",
    equal: "=",
    minus: "-",
    comma: ",",
    period: ".",
    slash: "/",
    semicolon: ";",
    apostrophe: "'",
    grave: "`",
    "mouse:272": "LEFT MOUSE BUTTON",
    "mouse:273": "RIGHT MOUSE BUTTON",
    "mouse:274": "MIDDLE MOUSE BUTTON",
    mouse_down: "SCROLL DOWN",
    mouse_up: "SCROLL UP",
    mouse_left: "SCROLL LEFT",
    mouse_right: "SCROLL RIGHT",
    XF86AudioRaiseVolume: "VOLUME UP",
    XF86AudioLowerVolume: "VOLUME DOWN",
    XF86AudioMute: "MUTE",
    XF86AudioMicMute: "MIC MUTE",
    XF86MonBrightnessUp: "BRIGHTNESS UP",
    XF86MonBrightnessDown: "BRIGHTNESS DOWN",
    XF86AudioNext: "NEXT",
    XF86AudioPrev: "PREV",
    XF86AudioPlay: "PLAY",
    XF86AudioPause: "PAUSE",
    XF86AudioStop: "STOP"
};

export function keyName(key) {
    if (Object.prototype.hasOwnProperty.call(KEYS, key))
        return KEYS[key];
    if (key.startsWith("XF86")) // XF86KbdBrightnessUp → KBD BRIGHTNESS UP
        return key.slice(4).replace(/([a-z0-9])([A-Z])/g, "$1 $2").toUpperCase();
    return key.toUpperCase();
}

export function chord(bind) {
    const mods = [];
    for (const [bit, name] of MODIFIERS) {
        if (bind.modmask & bit)
            mods.push(name);
    }
    const key = bind.key ? keyName(bind.key) : "CODE:" + bind.keycode;
    return mods.length ? mods.join(" ") + " + " + key : key;
}

// [{ chord, description }] in config order; the same description → one row, chords joined
export function rows(binds) {
    const out = [];
    const byDescription = {};
    for (const b of binds) {
        let description = b.description || "";
        if (b.submap)
            description += " (" + b.submap + ")";
        const c = chord(b);
        const seen = description ? byDescription[description] : undefined;
        if (seen) {
            seen.chord += " / " + c;
            continue;
        }
        const row = { chord: c, description: description };
        out.push(row);
        if (description)
            byDescription[description] = row;
    }
    return out;
}

export function parse(json) {
    let binds;
    try {
        binds = JSON.parse(json);
    } catch (e) {
        return [];
    }
    return Array.isArray(binds) ? rows(binds) : [];
}

export function chordWidth(list) {
    let width = 0;
    for (const r of list)
        width = Math.max(width, r.chord.length);
    return width;
}

export function pad(text, width) {
    return text.padEnd(width);
}

const words = text => text.toLowerCase().replace(/\+/g, " ").split(/\s+/).filter(w => w);

// Every word of the query must match: one character = a whole word of the chord or description (so "k"
// finds SUPER + K, not every description with a k), longer = part of the chord or description.
export function filter(list, query) {
    const wanted = words(query);
    if (!wanted.length)
        return list;
    return list.filter(r => {
        const text = (r.chord + " " + r.description).toLowerCase();
        const own = words(text);
        return wanted.every(w => w.length === 1 ? own.indexOf(w) >= 0 : text.indexOf(w) >= 0);
    });
}

// First shown row after scrolling by delta rows; the last page stays full
export function step(top, count, visible, delta) {
    return Math.max(0, Math.min(top + delta, count - visible));
}
