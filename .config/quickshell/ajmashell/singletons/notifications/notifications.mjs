// Pure logic of Ajmashell notifications (ticket 10): popup lifetime, history, popup replacement,
// the bell's badge and icon sources. A JS module (not QML) so tools/test-notifications.mjs can test it with node.
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
