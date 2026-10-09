// Pure logic of the Panel zasilania (power/PowerPanel.qml, ticket 18, D10): the six actions of the wlogout it
// replaces (~/.config/wlogout/layout: same commands and keys), moves between the buttons, and which actions
// logind allows (CanSuspend & co. — this laptop answers "na" for hibernation).
// Tests: ~/Projects/hyprland-lua-migration/tools/test-power.mjs
// Own implementation; keyboard moves after caelestia modules/session/Content.qml (idea only, see PowerPanel.qml).

// least to most disruptive, as in the ticket; key = wlogout's keybind
export const ACTIONS = [
    { id: "lock", label: "Lock", key: "l", icon: "\u{f033e}" }, // nf-md-lock
    { id: "logout", label: "Logout", key: "e", icon: "\u{f0343}" }, // nf-md-logout
    { id: "suspend", label: "Suspend", key: "u", icon: "\u{f0904}" }, // nf-md-power_sleep
    { id: "hibernate", label: "Hibernate", key: "h", icon: "\u{f0717}" }, // nf-md-snowflake
    { id: "reboot", label: "Reboot", key: "r", icon: "\u{f0709}" }, // nf-md-restart
    { id: "shutdown", label: "Shutdown", key: "s", icon: "\u{f0425}" }, // nf-md-power
];

// logind method asked for each action it decides (lock and logout are always possible)
export const CAN_METHODS = { suspend: "CanSuspend", hibernate: "CanHibernate", reboot: "CanReboot", shutdown: "CanPowerOff" };

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
    case "hibernate":
        return ["systemctl", "hibernate"];
    case "reboot":
        return ["systemctl", "reboot"];
    case "shutdown":
        return ["systemctl", "poweroff"];
    }
    return [];
}

// answers: { suspend: "yes" | "na" | …, … } — logind's Can* answers. Only "na" (not possible here) and "no"
// (not allowed) hide an action; "challenge" asks for a password through the polkit agent (hyprpolkitagent), and an
// unknown answer (not back yet, busctl failed) keeps it, as wlogout always did.
export function allowed(answers) {
    return ACTIONS.map(a => answers[a.id] !== "na" && answers[a.id] !== "no");
}

// next button in the direction delta (±1), round the row, skipping disallowed ones; -1 = none selected yet
export function step(index, count, delta, allowedList) {
    let next = index < 0 ? (delta > 0 ? 0 : count - 1) : (index + delta + count) % count;
    for (let tries = 0; tries < count && allowedList && !allowedList[next]; tries++)
        next = (next + delta + count) % count;
    return next;
}

// `busctl call … CanHibernate` prints `s "na"`
export function parseCan(output) {
    const match = /"([^"]*)"/.exec(output || "");
    return match ? match[1] : "";
}

// one run for all four questions; a failed call prints an empty line, so line n stays method n
export function canCommand() {
    const methods = Object.keys(CAN_METHODS).map(id => CAN_METHODS[id]).join(" ");
    return ["sh", "-c", `for m in ${methods}; do busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager "$m" 2>/dev/null || echo; done`];
}

export function parseCans(output) {
    const lines = (output || "").split("\n");
    const answers = {};
    // a plain loop: Qt's JS engine returned {} from forEach((id, i) => answers[id] = …) here (2026-10-09; node passes)
    const ids = Object.keys(CAN_METHODS);
    for (let i = 0; i < ids.length; i++)
        answers[ids[i]] = parseCan(lines[i]);
    return answers;
}
