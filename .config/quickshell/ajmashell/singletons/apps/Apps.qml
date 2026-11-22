// Starts programs for the shell through Hyprland (apps.mjs execRequest): the launcher, the Panel zasilania,
// the Wi-Fi island's right click and the Orbita's "program" button. One place instead of a
// Hyprland.dispatch(…) copy in each component (ticket 23).
// Ticket c22: an app that already has a window is shown instead of started again (nothing happened before):
// the launcher goes to the window's workspace (showApp "goto"), app shortcuts bring the window to the focused
// workspace (IPC `apps bring`, hypr/scripts/focus-or-run.sh). One logic for both: apps.mjs showRequests.
// Ticket c14: a double click on the media island / popup goes to the shown player's window (goToApp).

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "apps.mjs" as Logic

Singleton {
    id: root

    // every Hyprland window as a plain object for apps.mjs and the launcher's Windows mode; focus order lives in
    // lastIpcObject (Hyprland.refreshToplevels()), the workspace is followed live
    readonly property var windows: Hyprland.toplevels.values.map(t => {
        const ipc = t.lastIpcObject;
        const appId = ipc.class || t.wayland?.appId || "";
        const entry = DesktopEntries.heuristicLookup(appId);
        return {
            address: t.address.startsWith("0x") ? t.address : "0x" + t.address,
            title: t.title || appId,
            appId: appId,
            workspace: t.workspace?.name ?? ipc.workspace?.name ?? "",
            focusHistory: ipc.focusHistoryID ?? -1,
            pid: ipc.pid ?? -1, // the privacy dot finds an app's window by its process (faza C ticket 05)
            entryId: entry?.id ?? "",
            icon: entry?.icon ?? appId
        };
    })

    // command: argv list; workingDirectory: "" = Hyprland's
    function run(command: list<string>, workingDirectory: string): void {
        Hyprland.dispatch(Logic.execRequest(command, workingDirectory));
    }

    // focus a window on any workspace and monitor
    function focusWindow(address: string): void {
        Hyprland.dispatch(Logic.focusRequest(address));
    }

    // shows the last used window of the entry's app; false = no window (not running or only in the tray), the
    // caller starts the program. mode: "goto" (the window's workspace) or "bring" (to the focused workspace)
    function showApp(entry: DesktopEntry, mode: string): bool {
        return show(entryInfo(entry), mode);
    }

    // info: { id, startupClass } (apps.mjs showRequests)
    function show(info: var, mode: string): bool {
        const requests = Logic.showRequests(info, windows, mode, Hyprland.focusedWorkspace?.name ?? "");
        requests.forEach(r => Hyprland.dispatch(r));
        return requests.length > 0;
    }

    // Ticket c14: a double click on the media island or popup goes to the last used window of the shown player's
    // app (desktopId = MPRIS DesktopEntry, media.mjs appId) on its workspace and monitor, as the launcher does.
    // false = no window (only in the tray, no GUI): the caller asks the player to raise itself.
    function goToApp(desktopId: string): bool {
        const entry = DesktopEntries.byId(desktopId);
        const info = entry ? entryInfo(entry) : {
            id: desktopId,
            startupClass: ""
        };
        if (!desktopId || Logic.showRequests(info, windows, "goto", "").length === 0)
            return false;
        showFresh(info, "goto");
        return true;
    }

    // focus order (lastIpcObject) is only as fresh as the last refresh (the launcher's opening): ask Hyprland again
    // and pick the window once it has answered
    function showFresh(info: var, mode: string): void {
        Hyprland.refreshToplevels();
        pending = {
            info: info,
            mode: mode
        };
        showTimer.restart();
    }

    function entryInfo(entry: DesktopEntry): var {
        return {
            id: entry.id,
            startupClass: entry.startupClass
        };
    }

    // the emergency Wi-Fi program (D2): enterprise / WEP networks the Orbita leaves to it
    function networkEditor(): void {
        run(["nm-connection-editor"], "");
    }

    IpcHandler {
        target: "apps"

        // app shortcuts: "shown" = a window of the .desktop entry (id without ".desktop") came to the focused
        // workspace; anything else (also no shell running) = focus-or-run.sh starts the program
        function bring(desktopId: string): string {
            const entry = DesktopEntries.byId(desktopId);
            if (!entry || Logic.showRequests(root.entryInfo(entry), root.windows, "bring", "").length === 0)
                return "none";
            root.showFresh(root.entryInfo(entry), "bring");
            return "shown";
        }
    }

    property var pending: null // { info, mode } of showFresh

    Timer {
        id: showTimer
        interval: 100 // a Hyprland IPC reply takes a few ms
        onTriggered: root.show(root.pending.info, root.pending.mode)
    }
}
