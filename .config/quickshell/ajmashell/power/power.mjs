// Pure logic of the Panel zasilania (power/PowerPanel.qml, ticket 18, D10): the actions of the wlogout it replaces
// (~/.config/wlogout/layout: same commands and keys) and moves between the buttons. No Hibernate: the kernel has it
// off on this laptop (/sys/power/disk = [disabled], logind CanHibernate = "na"), user 2026-10-09: remove the button.
// Tests: ~/Projects/hyprland-lua-migration/tools/test-power.mjs
// Own implementation; keyboard moves after caelestia modules/session/Content.qml (idea only, see PowerPanel.qml).

// least to most disruptive, as in the ticket; key = wlogout's keybind
export const ACTIONS = [
    { id: "lock", label: "Lock", key: "l", icon: "\u{f033e}" }, // nf-md-lock
    { id: "logout", label: "Logout", key: "e", icon: "\u{f0343}" }, // nf-md-logout
    { id: "suspend", label: "Suspend", key: "u", icon: "\u{f0904}" }, // nf-md-power_sleep
    { id: "reboot", label: "Reboot", key: "r", icon: "\u{f0709}" }, // nf-md-restart
    { id: "shutdown", label: "Shutdown", key: "s", icon: "\u{f0425}" }, // nf-md-power
];

export function actionForKey(text) {
    const key = (text || "").toLowerCase();
    return key ? ACTIONS.find(a => a.key === key) ?? null : null;
}

// env: { home, sessionId } (XDG_SESSION_ID of the shell; empty → logind picks the caller's session)
export function command(action, env) {
    switch (action.id) {
    case "lock":
        return [`${env.home}/.config/hypr/scripts/hyprlock.sh`];
    case "logout":
        return ["loginctl", "kill-session", env.sessionId || "auto"];
    case "suspend":
        return ["systemctl", "suspend"];
    case "reboot":
        return ["systemctl", "reboot"];
    case "shutdown":
        return ["systemctl", "poweroff"];
    }
    return [];
}

// next button in the direction delta (±1), round the row; -1 = none selected yet
export function step(index, count, delta) {
    return index < 0 ? (delta > 0 ? 0 : count - 1) : (index + delta + count) % count;
}
