// DriveSection — the Dyski section of the Centrum sterowania (faza C ticket 06; user decisions 2026-11-10): one row
// per removable drive (USB stick, SD card), only while one is plugged in; without one the section takes no space.
// A row's eject button unmounts every mounted filesystem and powers the drive off (safe to pull out); a click on the
// row opens it in the file manager (ControlCenter.openFiles: Nautilus — the Centrum is for the mouse, user).
// No polling: the list is read (`lsblk -J -b`) on each opening of the Centrum (fresh use) and whenever
// `udisksctl monitor` reports a change while the Centrum is open. Quickshell has no udisks API (ticket).
// udiskie keeps mounting new drives (faza B ticket 23, without its tray icon).
// Own implementation; logic in drives.mjs (tests tools/test-control-drives.mjs).

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.singletons.theme
import "drives.mjs" as Logic

Column {
    id: root

    property bool active: false // the Centrum is shown: read the list, follow udisks
    property var drives: []
    property string ejecting: "" // device path of the drive being ejected
    property var errors: ({}) // device path → text of the last failed eject; cleared on each opening

    signal opened(string mountpoint)

    visible: drives.length > 0
    spacing: Theme.spacing.md

    function refresh(): void {
        lsblk.running = false; // a change during a read starts it again, not lost
        lsblk.running = true;
    }

    function eject(drive: var): void {
        if (ejecting !== "")
            return;
        const next = Object.assign({}, errors);
        delete next[drive.path];
        errors = next;
        ejecting = drive.path;
        ejectProc.command = Logic.ejectCommand(drive);
        ejectProc.running = true;
    }

    onActiveChanged: {
        if (active) {
            errors = {};
            refresh();
        }
    }

    Process {
        id: lsblk
        command: Logic.LSBLK_COMMAND
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.drives = Logic.removableDrives(JSON.parse(text));
                } catch (e) {
                    root.drives = [];
                }
            }
        }
    }

    // one line per event (Added, Removed, Properties Changed and their details): read the list once they settle
    Process {
        running: root.active
        command: ["udisksctl", "monitor"]
        stdout: SplitParser {
            onRead: settle.restart()
        }
    }

    Timer {
        id: settle
        interval: 300
        onTriggered: root.refresh()
    }

    Process {
        id: ejectProc
        // udisksctl writes to stderr only when it fails
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "" || root.ejecting === "")
                    return;
                const next = Object.assign({}, root.errors);
                next[root.ejecting] = Logic.ejectError(text);
                root.errors = next;
            }
        }
        onRunningChanged: {
            if (running)
                return;
            Qt.callLater(() => root.ejecting = ""); // after stderr's text, which names the drive by ejecting
            root.refresh();
        }
    }

    Repeater {
        model: root.drives

        DriveRow {
            required property var modelData

            width: root.width
            title: modelData.title
            text: root.errors[modelData.path] ?? modelData.text
            openable: modelData.mountpoint !== ""
            ejecting: root.ejecting === modelData.path
            canEject: root.ejecting === ""
            onOpened: root.opened(modelData.mountpoint)
            onEjected: root.eject(modelData)
        }
    }
}
