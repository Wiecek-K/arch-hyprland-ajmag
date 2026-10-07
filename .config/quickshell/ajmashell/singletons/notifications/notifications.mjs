// Pure logic of Ajmashell notifications (ticket 10): popup lifetime, history, popup replacement,
// the bell's badge and icon sources; the full Notification centre (ticket 16): groups per app, action buttons,
// progress bars and the saved silent mode. A JS module (not QML) so tools/test-notifications.mjs can test it with node.
// Popup timeouts from our swaync (~/.config/swaync/config.json: timeout-low 3, timeout 6, timeout-critical 0);
// icon source rules from serpantinum notifications/types/Default.qml (idea only):
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a

const LOW = 0; // NotificationUrgency.Low
const CRITICAL = 2; // NotificationUrgency.Critical

// our Waybar "custom/swaync" format-icons: "none" / "notification" and "dnd-none" / "dnd-notification"
export const BELL_ICON = "\u{f0a2}";
const BELL_SILENT_ICON = "\u{f1f7}";
export const BELL_ICONS = [BELL_ICON, BELL_SILENT_ICON];

export function bellIcon(silent) {
    return silent ? BELL_SILENT_ICON : BELL_ICON;
}

// Silent mode (DND, right click on the bell): notifications go to the history without a popup;
// critical ones still pop up (serpantinum NotificationPopups.qml does the same).
export function popupAllowed({ silent, urgency }) {
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
