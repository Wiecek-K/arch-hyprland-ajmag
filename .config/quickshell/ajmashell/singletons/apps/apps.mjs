// Pure logic of Apps.qml: the Hyprland dispatch that starts a program for the shell.
// A JS module (not QML) so tools/test-apps.mjs can test it with node. Moved from launcher/launcher.mjs (ticket 23).

import { luaString, luaValue } from "../../bar/workspaces.mjs";

const shellQuote = arg => `'${String(arg).replace(/'/g, "'\\''")}'`;

// Argument for Hyprland.dispatch(): Hyprland starts the app, as it did with rofi, so the window gets a fresh
// workspace token. Started by qs it would inherit the shell's HL_INITIAL_WORKSPACE_TOKEN and, with
// misc:initial_workspace_tracking = 2, open on the workspace where the shell was started; it would also live in
// the cgroup of ajmashell.service and die with each restart of the shell (ticket 23).
export function execRequest(command, workingDirectory = "") {
    const cmd = command.map(shellQuote).join(" ");
    return `hl.dsp.exec_cmd(${luaString(workingDirectory ? `cd ${shellQuote(workingDirectory)} && ${cmd}` : cmd)})`;
}

// Argument for Hyprland.dispatch(): focus a window, on any workspace and monitor (launcher's Windows mode, ticket c22)
export function focusRequest(address) {
    return `hl.dsp.focus({ window = ${luaString("address:" + address)} })`;
}

// A window of the .desktop entry: Quickshell's lookup for its class, or the class equal to the entry id or
// StartupWMClass (any letter case; Slack has class "Slack", entry "slack").
function matches(entry, w) {
    if (w.entryId && w.entryId === entry.id)
        return true;
    const cls = w.appId.toLowerCase();
    return cls !== "" && [entry.id, entry.startupClass].some(name => name && name.toLowerCase() === cls);
}

// Ticket c22: a launch of an app that already has a window shows that window instead of doing nothing.
// entry: { id, startupClass } of the .desktop entry; windows: [{ address, appId, workspace, focusHistory, entryId }]
// (entryId = DesktopEntries.heuristicLookup(appId)?.id); of several windows the last used one.
// mode "goto" (launcher): focus the window on its workspace and monitor; "bring" (app shortcuts, user 2026-11-03):
// move it to the focused workspace first. Returns the dispatches; [] = no window (app not running or only in
// the tray), start the program as before.
export function showRequests(entry, windows, mode, workspace) {
    const rank = w => w.focusHistory < 0 ? Infinity : w.focusHistory; // -1 = Hyprland has not told us yet
    const w = windows.filter(w => matches(entry, w)).sort((x, y) => rank(x) - rank(y))[0];
    if (!w)
        return [];
    const focus = focusRequest(w.address);
    if (mode !== "bring" || w.workspace === workspace)
        return [focus];
    const window = luaString("address:" + w.address);
    return [`hl.dsp.window.move({ workspace = ${luaValue(workspace)}, follow = false, window = ${window} })`, focus];
}
