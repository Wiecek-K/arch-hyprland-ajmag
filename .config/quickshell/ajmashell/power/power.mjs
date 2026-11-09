// Pure logic of the Panel zasilania (power/PowerPanel.qml, ticket 18, D10): the actions of the wlogout it replaces
// (wlogout/layout, dotfiles tag fallback-set-before-23: same commands; keys were wlogout's l e u r s until faza C
// ticket 26, now S suspends and Q shuts down, user 2026-11-03) and moves between the buttons. No Hibernate: the kernel has it
// off on this laptop (/sys/power/disk = [disabled], logind CanHibernate = "na"), user 2026-10-09: remove the button.
// Tests: ~/Projects/hyprland-lua-migration/tools/test-power.mjs
// Own implementation; keyboard moves after caelestia modules/session/Content.qml (idea only, see PowerPanel.qml).

// least to most disruptive, as in the ticket; key runs the action at once (ticket 26: Suspend u → s, Shutdown s → q)
export const ACTIONS = [
    { id: "lock", label: "Lock", key: "l", icon: "\u{f033e}" }, // nf-md-lock
    { id: "logout", label: "Logout", key: "e", icon: "\u{f0343}" }, // nf-md-logout
    { id: "suspend", label: "Suspend", key: "s", icon: "\u{f0904}" }, // nf-md-power_sleep
    { id: "reboot", label: "Reboot", key: "r", icon: "\u{f0709}" }, // nf-md-restart
    { id: "shutdown", label: "Shutdown", key: "q", icon: "\u{f0425}" }, // nf-md-power
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

// Suspend waits until the panel is off the screen (faza C ticket 16): Hyprland's clock stops in sleep, so a
// suspend in the middle of the panel's fade-out froze it and the panel showed for 1–2 s after unlocking.
// The others: the session ends, or hyprlock covers the screen while the fade finishes behind it.
export function waitsForClose(action) {
    return action?.id === "suspend";
}

// next button in the direction delta (±1), round the row; -1 = none selected yet
export function step(index, count, delta) {
    return index < 0 ? (delta > 0 ? 0 : count - 1) : (index + delta + count) % count;
}
