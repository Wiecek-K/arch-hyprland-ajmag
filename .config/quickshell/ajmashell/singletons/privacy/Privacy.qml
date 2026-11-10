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
    property var cameraApps: [] // camera-users.sh

    readonly property var rows: Logic.rows(
        watched.map(n => ({ id: n.id, props: n.properties })),
        Pipewire.links.values.map(l => ({ source: l.source?.id ?? -1, target: l.target?.id ?? -1 })),
        cameraApps)
    readonly property bool active: rows.length > 0

    // "Firefox — mikrofon, kamera"
    function rowText(row: var): string {
        return Logic.rowText(row);
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
                if (line.startsWith("users"))
                    root.cameraApps = line.split("\t").slice(1);
            }
        }
    }

    Timer {
        id: restart
        interval: 5000 // ms, the script's own longest wait
        onTriggered: cameraUsers.running = true
    }
}
