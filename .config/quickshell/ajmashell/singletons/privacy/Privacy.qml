// Privacy — which apps use the microphone, the camera or share the screen, for the Bar's privacy dot
// (faza C ticket 05), one for all screens. Rows: privacy.mjs `rows`; camera holders: camera-users.sh.
// Always watching: the dot must show whenever something starts recording.
// Own implementation; idea after DankMaterialShell quickshell/Services/PrivacyService.qml (MIT):
// https://github.com/AvengeMedia/DankMaterialShell/blob/4a51cd642ca08facf4c78940ef393fc1e880bcd1/quickshell/Services/PrivacyService.qml

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.singletons.apps
import "privacy.mjs" as Logic

Singleton {
    id: root

    // Nodes whose properties tell what they are. Quickshell has no type for "Stream/Input/Video" (a camera or
    // screencast reader) and "Stream/Input/Audio/Internal", so untracked nodes are read too; devices are not.
    readonly property var watched: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioInStream
        || n.type === PwNodeType.VideoSource || n.type === PwNodeType.Untracked)
    property var cameraApps: [] // camera-users.sh, [{ app, pid }]

    readonly property var rows: Logic.rows(
        watched.map(n => ({ id: n.id, props: n.properties })),
        Pipewire.links.values.map(l => ({ source: l.source?.id ?? -1, target: l.target?.id ?? -1 })),
        cameraApps)
    readonly property bool active: rows.length > 0

    // "Firefox — mikrofon, kamera"
    function rowText(row: var): string {
        return Logic.rowText(row);
    }

    // address of the window a click on the row focuses, "" = none (privacy.mjs windowFor);
    // processes = processes.sh's text, windows = Apps.windows
    function windowOf(row: var, processes: string, windows: var): string {
        return Logic.windowFor(row, Logic.parseProcesses(processes), windows);
    }

    // the tray icon of a row without a window, { service, path } or null (privacy.mjs trayFor)
    function trayOf(row: var, processes: string): var {
        return Logic.trayFor(row, Logic.parseProcesses(processes));
    }

    // what the list reads when it opens: process table, PipeWire clients' and tray icons' pids
    readonly property list<string> processesCommand: ["bash", Quickshell.shellDir + "/singletons/privacy/processes.sh"]

    // An app closed to the tray (Discord): its icon's Activate shows the window; Hyprland opens it on the focused
    // workspace, without focus (checked 2026-11-10), so focus it once it is there (user, 2026-11-10).
    property var pending: null // { row, processes } while waiting for the window

    function showFromTray(row: var, processes: string): void {
        const tray = trayOf(row, processes);
        if (!tray)
            return;
        Quickshell.execDetached(["busctl", "--user", "call", tray.service, tray.path, "org.kde.StatusNotifierItem",
            "Activate", "ii", "0", "0"]);
        pending = { row: row, processes: processes };
        waitWindow.tries = 0;
        waitWindow.restart();
    }

    // a new window's pid (lastIpcObject) comes only with a refresh: ask until it shows up, for 3 s at most
    Timer {
        id: waitWindow
        property int tries: 0
        interval: 200
        repeat: true
        onTriggered: {
            const address = root.pending ? root.windowOf(root.pending.row, root.pending.processes, Apps.windows) : "";
            if (address !== "" || ++tries >= 15) {
                if (address !== "")
                    Apps.focusWindow(address);
                root.pending = null;
                stop();
                return;
            }
            Hyprland.refreshToplevels();
        }
    }

    // without a tracker the nodes' properties stay empty
    PwObjectTracker {
        objects: root.watched
    }

    Process {
        id: cameraUsers
        command: ["bash", Quickshell.shellDir + "/singletons/privacy/camera-users.sh"]
        running: true
        // the script runs for the shell's whole life; if it dies anyway, forget its apps and start it again
        onExited: {
            root.cameraApps = [];
            restart.start();
        }
        stdout: SplitParser {
            onRead: line => {
                const apps = Logic.cameraApps(line);
                if (apps)
                    root.cameraApps = apps;
            }
        }
    }

    Timer {
        id: restart
        interval: 5000 // ms, the script's own longest wait
        onTriggered: cameraUsers.running = true
    }
}
