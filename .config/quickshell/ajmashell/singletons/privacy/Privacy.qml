// Privacy — which apps use the microphone, the camera or share the screen, for the Bar's privacy dot
// (faza C ticket 05), one for all screens. Rows: privacy.mjs `rows`; camera holders: camera-users.sh.
// Always watching: the dot must show whenever something starts recording.
// Own implementation; idea after DankMaterialShell quickshell/Services/PrivacyService.qml (MIT):
// https://github.com/AvengeMedia/DankMaterialShell/blob/4a51cd642ca08facf4c78940ef393fc1e880bcd1/quickshell/Services/PrivacyService.qml

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
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
    // processes = the text of `processesCommand`, windows = Apps.windows
    function windowOf(row: var, processes: string, windows: var): string {
        return Logic.windowFor(row, Logic.parseProcesses(processes), windows);
    }

    // the process table and the pid of each PipeWire client (privacy.mjs parseProcesses); Quickshell has no
    // PipeWire clients, and a native client's stream (pw-record, OBS) carries no pid of its own
    readonly property list<string> processesCommand: ["sh", "-c", "ps -e -o pid=,ppid=; echo clients; "
        + "pw-dump | jq -r '.[] | select(.type == \"PipeWire:Interface:Client\") | "
        + "\"\\(.id) \\(.info.props[\"application.process.id\"] // .info.props[\"pipewire.sec.pid\"] // \"\")\"'"]

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
