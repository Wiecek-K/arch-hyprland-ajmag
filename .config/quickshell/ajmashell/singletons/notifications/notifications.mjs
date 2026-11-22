// Pure logic of Ajmashell notifications (ticket 10): popup lifetime, history, popup replacement,
// the bell's badge and icon sources; the full Notification centre (ticket 16): groups per app, action buttons,
// progress bars and the saved silent mode. A JS module (not QML) so tools/test-notifications.mjs can test it with node.
// Popup timeouts from our old swaync (swaync/config.json, dotfiles tag fallback-set-before-23: timeout-low 3, timeout 6, timeout-critical 0);
// icon source rules from serpantinum notifications/types/Default.qml (idea only):
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a

import { execRequest, focusRequest } from "../apps/apps.mjs";

const LOW = 0; // NotificationUrgency.Low
const CRITICAL = 2; // NotificationUrgency.Critical

// our old Waybar "custom/swaync" format-icons: "none" / "notification" and "dnd-none" / "dnd-notification"
export const BELL_ICON = "\u{f0a2}";
const BELL_SILENT_ICON = "\u{f1f7}";
export const BELL_ICONS = [BELL_ICON, BELL_SILENT_ICON];

export function bellIcon(silent) {
    return silent ? BELL_SILENT_ICON : BELL_ICON;
}

// Silent mode (DND, right click on the bell): notifications go to the history without a popup;
// critical ones still pop up (serpantinum NotificationPopups.qml does the same).
// While the Centrum is open no popup at all, critical too: its list shows every entry, and popups lay over it
// (user, 2026-11-01, faza C ticket 03).
export function popupAllowed({ silent, urgency, centrumOpen }) {
    if (centrumOpen)
        return false;
    return !silent || urgency === CRITICAL;
}

// Kept in memory only (no history on disk, README 2026-09-26); the oldest go first.
export const HISTORY_LIMIT = 50;

// ms a popup stays; 0 = until clicked. expireTimeout: -1 = server default, 0 = never (freedesktop spec).
export function popupTimeout({ urgency, expireTimeout }) {
    if (urgency === CRITICAL || expireTimeout === 0)
        return 0;
    if (expireTimeout > 0)
        return expireTimeout;
    return urgency === LOW ? 3000 : 6000;
}

// transient (notify-send -e, volume.sh, brightness.sh): popup only, never in the history or the bell's count
export function keptInHistory({ transient }) {
    return !transient;
}

// Notifications with the same key replace each other's popup (volume and brightness levels);
// Quickshell does not handle this hint itself.
export function syncKey(hints) {
    const key = hints?.["x-canonical-private-synchronous"];
    return key === undefined || key === null ? "" : String(key);
}

// Indexes of current popups (by their sync keys) that a new popup with `key` replaces.
export function replacedPopups(keys, key) {
    if (!key)
        return [];
    const indexes = []; // no Array.flatMap in Qt's JS engine (TypeError in qs, 2026-10-02)
    keys.forEach((other, index) => {
        if (other === key)
            indexes.push(index);
    });
    return indexes;
}

// Count on the bell's badge; empty = no badge. Capped so the badge keeps its size.
export function badgeText(count) {
    if (count <= 0)
        return "";
    return count > 9 ? "9+" : String(count);
}

// Image source for appIcon / image: URLs as they are, absolute paths as files, names from the icon theme.
export function iconSource(icon) {
    if (!icon)
        return "";
    if (/^(file|image|https?):\/\//.test(icon))
        return icon;
    return icon.startsWith("/") ? `file://${icon}` : `image://icon/${icon}`;
}

// Image source for the notification's image (image-data / image-path hint). Quickshell gives a path as
// image://icon/<path>, and the icon provider draws its missing-icon checkerboard (status Ready) when the file is gone:
// satty sends a temp file and deletes it at once. As file:// a missing file gives Image.Error, so the card shows
// the app icon instead.
export function imageSource(image) {
    if (!image)
        return "";
    if (image.startsWith("image://icon//"))
        return `file://${image.slice("image://icon/".length)}`;
    return iconSource(image);
}

// Icon names to try for the app, in order: app_icon, the icon of the desktop-entry hint's entry, the icon of the
// app name's entry, the app name itself (satty: no app_icon, desktop-entry com.gabm.satty has no file, satty.desktop
// has Icon=satty). The caller keeps the first one the icon theme has.
export function appIconCandidates({ appIcon, desktopEntryIcon, appNameEntryIcon, appName } = {}) {
    const names = [];
    [appIcon, desktopEntryIcon, appNameEntryIcon, appName].forEach(name => {
        const trimmed = (name ?? "").trim();
        if (trimmed && !names.includes(trimmed))
            names.push(trimmed);
    });
    return names;
}

// How many of the oldest history entries to drop at `count` entries.
export function overLimit(count) {
    return Math.max(0, count - HISTORY_LIMIT);
}

// --- full Notification centre (ticket 16) ---

// One group per app. Notifications without an app name (bare `notify-send -a ""`) share one group.
export const OTHER_GROUP = "Other";

export function groupKey(appName) {
    const name = (appName ?? "").trim();
    return name || OTHER_GROUP;
}

// The history is kept grouped: groups by their newest entry, newest first inside a group. A group is
// one run of entries, so a new notification moves its group's block to the top and goes in above it.
export function groupBlock(keys, key) {
    const from = keys.indexOf(key);
    if (from < 0)
        return null;
    let count = 0;
    while (from + count < keys.length && keys[from + count] === key)
        count++;
    return { from, count };
}

export function groupCounts(keys) {
    const counts = {};
    keys.forEach(key => counts[key] = (counts[key] ?? 0) + 1);
    return counts;
}

// Edges of the next cards under a collapsed group in the Centrum, like a stack (ticket 32; user, 2026-10-09:
// one edge for 2 entries, two for 3 or more). An expanded group shows every card, so no edges.
export const STACK_MAX_EDGES = 2;

export function stackEdges(count, open) {
    return open ? 0 : Math.min(Math.max(count - 1, 0), STACK_MAX_EDGES);
}

// Index of the oldest entry by arrival number (the last entry belongs to the quietest group, not the oldest one).
export function oldestIndex(arrivals) {
    let index = -1;
    arrivals.forEach((arrival, i) => {
        if (index < 0 || arrival < arrivals[index])
            index = i;
    });
    return index;
}

// Buttons under a notification: every labelled action except "default", which is the click on the card.
export function actionButtons(actions) {
    return (actions ?? []).filter(a => a.identifier !== "default" && a.text)
        .map(a => ({ identifier: a.identifier, text: a.text }));
}

// Progress bar: the `value` hint (freedesktop spec, 0–100) as whole percent; -1 = no bar.
export function progressValue(hints) {
    const value = hints?.value;
    if (value === undefined || value === null || value === "")
        return -1;
    const number = Number(value);
    if (!Number.isFinite(number))
        return -1;
    return Math.round(Math.max(0, Math.min(100, number)));
}

// Silent mode survives a restart (~/.local/state/ajmashell/notifications.json); anything unreadable = off.
export function parseState(text) {
    try {
        return { silent: JSON.parse(text).silent === true };
    } catch (e) {
        return { silent: false };
    }
}

export function formatState({ silent }) {
    return JSON.stringify({ silent: silent === true }) + "\n";
}

// close button on a card in the Centrum (ticket 32): nf-fa-xmark
export const CLOSE_ICON = "\u{f00d}";

// group header in the Centrum: chevron of a group with more than one entry (Nerd Font md-chevron-down / -up)
export const GROUP_CLOSED_ICON = "\u{f0140}";
export const GROUP_OPEN_ICON = "\u{f0143}";

// Time on a card (user, 2026-10-07): "now" under a minute, minutes under an hour, the clock today, else date and clock.
export function timeText(time, now) {
    const minutes = Math.floor((now - time) / 60000);
    if (minutes < 1)
        return "now";
    if (minutes < 60)
        return `${minutes} min`;
    const at = new Date(time);
    const clock = `${String(at.getHours()).padStart(2, "0")}:${String(at.getMinutes()).padStart(2, "0")}`;
    if (at.toDateString() === new Date(now).toDateString())
        return clock;
    return `${at.getDate()}.${at.getMonth() + 1} ${clock}`;
}

// Window to focus after a click on a card (user, 2026-10-07): a native Wayland app (Slack) gets no activation
// token from the action, so Hyprland ignores its own focus request. Match the window class with the desktop entry
// or the app name, case-insensitive; with several windows the one focused last. windows: [{ address, appId,
// focusHistory }] as in launcher.mjs (focusHistory 0 = focused now, -1 = never). "" = no window.
export function appWindow(windows, { desktopEntry, appName }) {
    const names = [desktopEntry, appName].filter(name => name).map(name => name.toLowerCase());
    if (names.length === 0)
        return "";
    const recent = w => w.focusHistory < 0 ? Infinity : w.focusHistory;
    const matching = windows.filter(w => names.includes((w.appId ?? "").toLowerCase()))
        .sort((a, b) => recent(a) - recent(b));
    return matching.length > 0 ? matching[0].address : "";
}

// Sender's own window (user, 2026-10-07): a script run in a terminal (the claude-notify hook of Claude Code) sends
// through notify-send, whose `sender-pid` hint is notify-send itself. Walking its parents up to a process that
// owns a window finds the exact terminal window, also with several kitty windows (one process each).
export function senderPid(hints) {
    const pid = Number(hints?.["sender-pid"]);
    return Number.isInteger(pid) && pid > 1 ? pid : 0;
}

// `ps` per step: /proc/<pid>/stat breaks on process names with spaces. Prints the pid, then each parent.
export function ancestryCommand(pid) {
    return ["sh", "-c", 'p=$1; while [ "$p" -gt 1 ] 2>/dev/null; do echo "$p"; p=$(ps -o ppid= -p "$p" | tr -d " "); done',
        "sh", String(pid)];
}

export function parsePids(text) {
    const pids = [];
    text.split("\n").forEach(line => {
        const pid = parseInt(line.trim(), 10);
        if (Number.isInteger(pid))
            pids.push(pid);
    });
    return pids;
}

// windows: [{ address, pid }]; pids: sender first, then its parents. "" = none of them has a window.
export function senderWindow(windows, pids) {
    for (const pid of pids) {
        const window = windows.find(w => w.pid === pid);
        if (window)
            return window.address;
    }
    return "";
}

// Click on a card: the dispatches for Hyprland.dispatch(). The sender's own terminal window first (claude-notify),
// else a window of the app by its name; [] = no window. Built here and not in QML, so the tests catch a
// missing function (ticket c32: QML still called launcher.mjs focusRequest after ticket c22 moved it to apps.mjs).
export function focusRequests(windows, pids, app) {
    const address = senderWindow(windows, pids) || appWindow(windows, app);
    return address ? [focusRequest(address)] : [];
}

// Click on satty's "File saved to '<path>'." (ticket c34, faza C): satty 0.22 sends no action and has no option for
// one, and its window is gone (--early-exit), so the click opens the folder of the saved file, also after "Save as"
// to another folder: the path in the body is where the file really is. xdg-open, so the default file manager
// (inode/directory in ~/.config/mimeapps.list, Nautilus) opens it. actions: the identifiers; an app's own "default"
// action wins. [] = not such a notification: the click focuses the app as before (ticket 32).
const SATTY_SAVED = /^File saved to '(\/[\s\S]*)'\.$/; // [\s\S], not the s flag: qmllint cannot parse it

export function savedFileRequests({ appName, desktopEntry, body, actions }) {
    const fromSatty = (appName ?? "").toLowerCase() === "satty" || desktopEntry === "com.gabm.satty";
    const path = fromSatty && !(actions ?? []).includes("default") ? SATTY_SAVED.exec(body ?? "")?.[1] : undefined;
    if (!path)
        return [];
    return [execRequest(["xdg-open", path.slice(0, path.lastIndexOf("/")) || "/"])];
}
