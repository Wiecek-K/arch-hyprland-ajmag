// DriveSection — the Sekcja Dyski of the Centrum sterowania (faza C ticket 06; user decisions 2026-11-10), at its
// bottom edge under a separator: one row per removable drive (USB stick, SD card), only while one is plugged in;
// without one the section takes no space.
// A row's eject button unmounts every mounted filesystem and powers the drive off (safe to pull out). A click on a
// mounted drive's row opens it in the file manager (ControlCenter.openFiles: Nautilus — the Centrum is for the mouse,
// user); on an unmounted one it mounts the drive, and only the next click — or the second click of a double click,
// even before the mount ends — opens it (user 2026-11-10).
// No polling: the list is read (`lsblk -J`) on each opening of the Centrum (fresh use) and whenever
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
    // device path of the drive being ejected / mounted; "" = none. One at a time
    property string ejecting: ""
    property string mounting: ""
    property string ejectTarget: "" // the ejected path, kept for the eject's stderr, which may end after the process
    property string openAfterMount: "" // device path clicked again while mounting: open it once mounted
    property var errors: ({}) // device path → text of the last failed eject or mount; cleared on each opening
    readonly property bool idle: ejecting === "" && mounting === ""

    signal opened(string mountpoint)

    visible: drives.length > 0
    spacing: Theme.spacing.md

    function refresh(): void {
        lsblk.running = false; // a change during a read starts it again, not lost
        lsblk.running = true;
    }

    function setError(path: string, text: string): void {
        const next = Object.assign({}, errors);
        if (text === "")
            delete next[path];
        else
            next[path] = text;
        errors = next;
    }

    function eject(drive: var): void {
        if (!idle)
            return;
        setError(drive.path, "");
        openAfterMount = "";
        ejecting = drive.path;
        ejectTarget = drive.path;
        ejectProc.command = Logic.ejectCommand(drive);
        ejectProc.running = true;
    }

    // a click on a row: open a mounted drive, mount an unmounted one; a click during its mount opens it after
    function activate(drive: var): void {
        if (drive.mountpoint !== "") {
            opened(drive.mountpoint);
        } else if (mounting === drive.path) {
            openAfterMount = drive.path;
        } else if (drive.mountable && idle) {
            setError(drive.path, "");
            mounting = drive.path;
            mountProc.command = Logic.mountCommand(drive);
            mountProc.running = true;
        }
    }

    onActiveChanged: {
        if (active) {
            errors = {};
            refresh();
        } else {
            openAfterMount = ""; // a mount still running must not open a window after the Centrum closed
        }
    }

    Process {
        id: lsblk
        command: Logic.LSBLK_COMMAND
        stdout: StdioCollector {
            onStreamFinished: {
                let next;
                try {
                    next = Logic.removableDrives(JSON.parse(text));
                } catch (e) {
                    return; // a read cut short by refresh(): its text is half a JSON, the next read follows
                }
                // a new array makes the Repeater build every row again (hover lost): only on a real change
                if (JSON.stringify(next) !== JSON.stringify(root.drives))
                    root.drives = next;
                // a mount ends only once the list shows it (or the drive is gone): a mount is faster than a double
                // click, and the second click must find "mounting", not the old unmounted row (mounted again: failed)
                if (root.mounting !== "") {
                    const drive = root.drives.find(d => d.path === root.mounting);
                    if (!drive || drive.mountpoint !== "") {
                        if (drive && root.openAfterMount === drive.path)
                            root.opened(drive.mountpoint);
                        root.openAfterMount = "";
                        root.mounting = "";
                    }
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
                if (text.trim() !== "")
                    root.setError(root.ejectTarget, Logic.ejectError(text));
            }
        }
        onRunningChanged: {
            if (running)
                return;
            root.ejecting = "";
            root.refresh();
        }
    }

    Process {
        id: mountProc
        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0) {
                root.setError(root.mounting, Logic.MOUNT_FAILED);
                root.openAfterMount = "";
                root.mounting = "";
            }
            root.refresh(); // on success it ends the mount (lsblk above)
        }
    }

    // above the rows, like the separators between the Centrum's other parts
    Rectangle {
        width: root.width
        height: 1
        color: Theme.control.separator
    }

    Repeater {
        model: root.drives

        DriveRow {
            required property var modelData

            width: root.width
            title: modelData.title
            text: root.errors[modelData.path] ?? modelData.text
            clickable: modelData.mountpoint !== "" || modelData.mountable
            busy: root.ejecting === modelData.path ? "Ejecting…" : root.mounting === modelData.path ? "Mounting…" : ""
            canEject: root.idle
            onActivated: root.activate(modelData)
            onEjected: root.eject(modelData)
        }
    }
}
