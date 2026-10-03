// Pure logic of the launcher (ticket 11): query kinds, app search and order, window list, focus dispatch,
// list navigation, the calculator's guard and the qalc command. A JS module (not QML) so
// tools/test-launcher.mjs can test it with node.
// Match quality (exact > prefix > contained > description > subsequence) adapted from serpantinum
// src/quickshell/launcher/Launcher.qml (executeFilter, isSubsequence):
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// Copyright (C) 2026 Illia Miroshnichenko — AGPL-3.0-or-later
// Changes: usage counts in rofi's "count id" format instead of app_rank.py (focus/launch/context ranks in
// Python); the generic name and keywords count as a description; the same scoring for the window list.
// Calculator: qalc through a Process like end-4/dots-hyprland ii/services/LauncherSearch.qml (mathProc):
// https://github.com/end-4/dots-hyprland/blob/547836f1b01a45445cfbbcd92b206d1b5ceee4d9/dots/.config/quickshell/ii/services/LauncherSearch.qml
// Own: the allowlist guard (qalc's command() runs programs, export()/save() write files) and the qalc flags.
// SPDX-License-Identifier: AGPL-3.0-or-later

import { luaString } from "../bar/workspaces.mjs";

export const CALC_PREFIX = "="; // user, 2026-10-01
export const MODES = ["apps", "windows"]; // rofi drun + window; no run, no filebrowser (B09 §1)
const TERMINAL = "kitty"; // keep in sync with ~/.config/hypr/configs/vars.lua `terminal`

// { kind: "calc", expr } when the text starts with "=", otherwise { kind: "search", query } (lower-case)
export function parseQuery(text) {
    if (text.startsWith(CALC_PREFIX))
        return { kind: "calc", expr: text.slice(CALC_PREFIX.length).trim() };
    return { kind: "search", query: text.trim().toLowerCase() };
}

function isSubsequence(sub, str) {
    let i = 0;
    for (let j = 0; i < sub.length && j < str.length; j++)
        if (sub[i] === str[j])
            i++;
    return i === sub.length;
}

// serpantinum's match quality; 0 = no match. `name` is the main text, `extra` the descriptive ones.
function matchScore(query, name, extra) {
    const n = name.toLowerCase();
    if (n === query)
        return 100000;
    if (n.startsWith(query))
        return 50000;
    if (n.includes(query))
        return 10000;
    if (extra.some(t => t.toLowerCase().includes(query)))
        return 5000;
    if (isSubsequence(query, n))
        return 1000;
    return 0;
}

const byName = (a, b) => a.name.localeCompare(b.name);

// apps: [{ id, name, genericName, comment, keywords }], query from parseQuery, usage: { id: launches }.
// Best match first, then most launched (rofi's history order), then alphabetical.
export function filterApps(apps, query, usage) {
    const scored = [];
    for (const app of apps) {
        const extra = [app.genericName || "", app.comment || ""].concat(app.keywords || []);
        const score = query ? matchScore(query, app.name, extra) : 0;
        if (!query || score > 0)
            scored.push({ app, score, used: usage[app.id] || 0 });
    }
    scored.sort((a, b) => b.score - a.score || b.used - a.used || byName(a.app, b.app));
    return scored.map(s => s.app);
}

// Usage file: "count id" per line, the format of rofi's ~/.cache/rofi3.druncache (that file is not read).
export function parseUsage(text) {
    const usage = {};
    for (const line of text.split("\n")) {
        const m = line.match(/^(\d+) (.+?)(?:\.desktop)?$/);
        if (m)
            usage[m[2]] = Number(m[1]);
    }
    return usage;
}

export function formatUsage(usage) {
    return Object.entries(usage).sort((a, b) => b[1] - a[1]).map(([id, n]) => `${n} ${id}\n`).join("");
}

export function addLaunch(usage, id) {
    const next = Object.assign({}, usage); // Qt's JS engine has no object spread
    next[id] = (usage[id] || 0) + 1;
    return next;
}

// windows: [{ address, title, appId, workspace, focusHistory }]; focusHistory 0 = focused now, -1 = never.
// No query: most recently focused first. Query: best match in the title or class first.
export function filterWindows(windows, query) {
    const recent = w => w.focusHistory < 0 ? Infinity : w.focusHistory;
    const scored = [];
    for (const w of windows) {
        const score = query ? Math.max(matchScore(query, w.title, [w.appId]), matchScore(query, w.appId, [])) : 0;
        if (!query || score > 0)
            scored.push({ w, score });
    }
    scored.sort((a, b) => b.score - a.score || recent(a.w) - recent(b.w));
    return scored.map(s => s.w);
}

// Argument for Hyprland.dispatch(); Hyprland switches the workspace and monitor itself.
export function focusRequest(address) {
    return `hl.dsp.focus({ window = ${luaString("address:" + address)} })`;
}

// rofi `cycle: true`: past the last row back to the first and the other way round.
// index -1 = nothing selected (calculator while typing): down goes to the first row, up to the last.
export function step(index, count, delta) {
    if (count <= 0)
        return 0;
    if (index < 0)
        return delta > 0 ? 0 : count - 1;
    return ((index + delta) % count + count) % count;
}

export function nextMode(mode) {
    return MODES[(MODES.indexOf(mode) + 1) % MODES.length];
}

export function terminalCommand(command) {
    return [TERMINAL, "-e"].concat(command);
}

const shellQuote = arg => `'${String(arg).replace(/'/g, "'\\''")}'`;

// Argument for Hyprland.dispatch(): Hyprland starts the app, as it did with rofi, so the window gets a fresh
// workspace token. Started by qs it would inherit the shell's HL_INITIAL_WORKSPACE_TOKEN and, with
// misc:initial_workspace_tracking = 2, open on the workspace where the shell was started.
export function execRequest(command, workingDirectory) {
    const cmd = command.map(shellQuote).join(" ");
    return `hl.dsp.exec_cmd(${luaString(workingDirectory ? `cd ${shellQuote(workingDirectory)} && ${cmd}` : cmd)})`;
}

// --- calculator ------------------------------------------------------------------
// Text after "=" is evaluated live, on every key press, so it must never run anything: qalc's command()
// starts programs (checked 2026-10-02: it created a file), export()/save() write files, plot() runs gnuplot.
// Only numbers, operators, brackets, "," (argument separator, e.g. log(100, 10)) and the names below pass;
// anything else never reaches qalc. No eval() in JS.
const NAMES = new Set(["sqrt", "cbrt", "root", "abs", "exp", "ln", "log", "log2", "log10", "sin", "cos", "tan",
    "asin", "acos", "atan", "sinh", "cosh", "tanh", "round", "floor", "ceil", "trunc", "mod", "rem", "pi", "e"]);
const NUMBER = /\d*\.?\d+(?:e[+-]?\d+)?/gi; // 2.5, .5, 1e3 (a lone "e" stays a name: Euler's number)
const WORD = /[a-z_][a-z0-9_]*/gi;
const SYMBOLS = /^[\s+\-*/^%().,!×÷−]*$/;

// { ok: true } or { ok: false, reason } (reason shown under the expression)
export function checkExpression(expr) {
    if (!expr.trim())
        return { ok: false, reason: "empty" };
    const rest = expr.replace(NUMBER, " ");
    const unknown = (rest.match(WORD) || []).filter(w => !NAMES.has(w));
    if (unknown.length)
        return { ok: false, reason: `unknown: ${unknown[0]}` };
    if (!SYMBOLS.test(rest.replace(WORD, " ")))
        return { ok: false, reason: "symbol" };
    return { ok: true };
}

// -t terse (only the result), +u8 ASCII output ("-" instead of "−", pastes anywhere), -m 2000 ms limit.
// The leading space keeps an expression such as "-5*3" from being read as an option.
export function calcCommand(expr) {
    return ["qalc", "-t", "+u8", "-m", "2000", " " + expr];
}

export function calcResult(stdout, exitCode) {
    const value = stdout.trim();
    return exitCode === 0 && value ? { ok: true, value } : { ok: false, value: "" };
}

// --- calculator history ----------------------------------------------------------
// Results copied with Enter (user, 2026-10-03); shown after a bare "=" in place of the examples.
export const CALC_HISTORY_SIZE = 5;

// history: [{ expr, value }], newest first
export function addCalc(history, expr, value) {
    return [{ expr, value }].concat(history.filter(h => h.expr !== expr)).slice(0, CALC_HISTORY_SIZE);
}

export function parseCalcHistory(text) {
    let list;
    try {
        list = JSON.parse(text);
    } catch (e) {
        return [];
    }
    if (!Array.isArray(list))
        return [];
    return list.filter(h => h && typeof h.expr === "string" && typeof h.value === "string")
        .map(h => ({ expr: h.expr, value: h.value })).slice(0, CALC_HISTORY_SIZE);
}

export function formatCalcHistory(history) {
    return JSON.stringify(history) + "\n";
}

// --- calculator keys -------------------------------------------------------------
// Buttons under the result (user, 2026-10-03): arrows reach them, Enter puts the text in at the cursor.
// Only names the guard allows; "()" = the cursor lands inside the brackets.
export const CALC_KEYS = [
    { label: "sqrt", insert: "sqrt()" }, { label: "^", insert: "^" }, { label: "%", insert: "%" },
    { label: "pi", insert: "pi" }, { label: "( )", insert: "()" },
    { label: "ln", insert: "ln()" }, { label: "log10", insert: "log10()" }, { label: "abs", insert: "abs()" },
    { label: "round", insert: "round()" }, { label: "!", insert: "!" },
    { label: "sin", insert: "sin()" }, { label: "cos", insert: "cos()" }, { label: "tan", insert: "tan()" },
    { label: "mod", insert: " mod " }, { label: "e", insert: "e" },
];

// text: the whole search field (with "="), cursor: its cursor position → { text, cursor }
export function insertKey(text, cursor, key) {
    const at = Math.max(cursor, CALC_PREFIX.length);
    const inside = key.insert.endsWith("()") ? 1 : 0;
    return { text: text.slice(0, at) + key.insert + text.slice(at), cursor: at + key.insert.length - inside };
}

// Arrows in calculator mode. Rows: history (after a bare "="), then the keys grid, `columns` wide.
// current -1 = nothing selected (typing). Returns the new index, or null when the arrow is not ours
// (left/right outside the grid move the text cursor).
export function calcMove(current, historyCount, keyCount, columns, key) {
    const total = historyCount + keyCount;
    if (current < historyCount) { // typing (-1) or a history row
        if (key === "left" || key === "right")
            return null;
        if (key === "down")
            return current + 1;
        return current > 0 ? current - 1 : total - 1;
    }
    const k = current - historyCount;
    switch (key) {
    case "right":
        return historyCount + (k + 1) % keyCount;
    case "left":
        return historyCount + (k - 1 + keyCount) % keyCount;
    case "down":
        return k + columns < keyCount ? current + columns : current;
    default: // up: the row above, from the top row the last history row or back to typing
        return k >= columns ? current - columns : historyCount - 1;
    }
}
