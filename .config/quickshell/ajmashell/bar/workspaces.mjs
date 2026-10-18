// Pure logic of the workspaces island: which numbers to show, Lua dispatch strings, wheel targets.
// A JS module (not QML) so tools/test-bar-workspaces.mjs can test it with node.
// luaString / luaValue from DankMaterialShell quickshell/Services/HyprlandService.qml:
// https://github.com/AvengeMedia/DankMaterialShell/blob/9dc5b2c5af7d18b7231f425fe0d8fa7243233109/quickshell/Services/HyprlandService.qml
// Copyright (c) 2025 Avenge Media LLC — MIT
// Changes: Lua dispatch only (config is Lua since phase A, no legacy `workspace N` branch).
// SPDX-License-Identifier: MIT

const ALWAYS_SHOWN = 5; // Waybar: "persistent-workspaces": { "*": 5 }
const SCROLL_LAST = 10; // the wheel reaches workspaces 1-10, empty ones too (user, 2026-09-29)

// ADR 0002 §8, variant A (user, 2026-09-29): 1-5 plus every existing workspace above 5.
// existingIds: ids of the workspaces Hyprland has now (they exist while they have windows or are shown).
export function shownIds(existingIds) {
    const ids = new Set();
    for (let id = 1; id <= ALWAYS_SHOWN; id++)
        ids.add(id);
    for (const id of existingIds)
        if (id > 0)
            ids.add(id);
    return [...ids].sort((a, b) => a - b);
}

export function luaString(value) {
    return `"${String(value ?? "").replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
}

export function luaValue(value) {
    const text = String(value ?? "");
    return /^[-+]?\d+$/.test(text) ? text : luaString(text);
}

// Argument for Hyprland.dispatch(): workspace id or name.
export function focusRequest(workspace) {
    return `hl.dsp.focus({ workspace = ${luaValue(workspace)} })`;
}

// Workspace number to focus after a wheel step from `current`, or null at the ends of 1-10 (no wrap-around).
// Unlike Waybar's "e+1" it goes through empty workspaces too. From a special workspace (id <= 0) up goes to 1.
export function scrollTarget(current, step) {
    if (current > SCROLL_LAST) // reached with SUPER+key; down comes back into the range
        return step < 0 ? SCROLL_LAST : null;
    const target = Math.max(current, 0) + step;
    return target >= 1 && target <= SCROLL_LAST ? target : null;
}
