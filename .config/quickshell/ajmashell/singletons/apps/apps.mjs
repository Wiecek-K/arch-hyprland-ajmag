// Pure logic of Apps.qml: the Hyprland dispatch that starts a program for the shell.
// A JS module (not QML) so tools/test-apps.mjs can test it with node. Moved from launcher/launcher.mjs (ticket 23).

import { luaString } from "../../bar/workspaces.mjs";

const shellQuote = arg => `'${String(arg).replace(/'/g, "'\\''")}'`;

// Argument for Hyprland.dispatch(): Hyprland starts the app, as it did with rofi, so the window gets a fresh
// workspace token. Started by qs it would inherit the shell's HL_INITIAL_WORKSPACE_TOKEN and, with
// misc:initial_workspace_tracking = 2, open on the workspace where the shell was started; it would also live in
// the cgroup of ajmashell.service and die with each restart of the shell (ticket 23).
export function execRequest(command, workingDirectory = "") {
    const cmd = command.map(shellQuote).join(" ");
    return `hl.dsp.exec_cmd(${luaString(workingDirectory ? `cd ${shellQuote(workingDirectory)} && ${cmd}` : cmd)})`;
}
