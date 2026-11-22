// PrivacyPopup — a click on the Bar's privacy dot (faza C ticket 05): one row per app using the microphone, the
// camera or the screen, "Firefox — mikrofon, kamera" (user, 2026-11-10: a small list under the dot).
// A click on a row focuses that app's window and closes the list (user, 2026-11-10); an app without a window but
// with a tray icon (Discord closed to the tray) shows its window on the focused workspace; a row with neither is
// dimmed. Window and icon: privacy.mjs windowFor / trayFor, from processes.sh read when the list opens.
// Dressed and placed like the tray menu (bar/TrayMenu.qml, Theme.bar.menu). Closes on a click outside
// (HyprlandFocusGrab), on Esc (BarPopups), on a second click on the dot and when nothing records any more.
// Own implementation.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.singletons.apps
import qs.singletons.barpopups
import qs.singletons.privacy
import qs.singletons.theme

PopupWindow {
    id: root

    required property Item source // the privacy island
    property string processes: "" // processes.sh's text, read when the list opens and when its rows change
    readonly property var table: Privacy.parseProcesses(processes) // parsed once per read, for every row

    function toggle(): void {
        visible = !visible;
    }

    visible: false
    anchor.item: source
    anchor.rect.x: 0
    anchor.rect.y: 0
    anchor.rect.width: source.width
    anchor.rect.height: source.height + Theme.bar.tooltip.gap
    // qmltypes give these as Edges::Flags, which qmllint cannot resolve
    anchor.edges: Edges.Bottom // qmllint disable missing-type
    anchor.gravity: Edges.Bottom // qmllint disable missing-type

    implicitWidth: Math.ceil(list.implicitWidth) + 2 * Theme.bar.menu.padding
    implicitHeight: Math.ceil(list.implicitHeight) + 2 * Theme.bar.menu.padding
    color: Theme.transparent // only the rounded box below is drawn

    Connections {
        target: Privacy

        function onActiveChanged(): void {
            if (!Privacy.active)
                root.visible = false;
        }

        function onRowsChanged(): void {
            if (root.visible)
                root.readProcesses();
        }
    }

    // The grab refuses a window that is not mapped yet, so arm it after the popup shows.
    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => grab.active = visible);
            readProcesses();
        } else {
            grab.active = false;
        }
    }

    // window pids (lastIpcObject) are only as fresh as the last refresh; the process table as fresh as the last read
    function readProcesses(): void {
        Hyprland.refreshToplevels();
        reader.running = true;
    }

    Process {
        id: reader
        command: Privacy.processesCommand
        stdout: StdioCollector {
            onStreamFinished: root.processes = text
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [root, ...BarPopups.bars]
        onCleared: root.visible = false
    }

    // closes on a press on the Bar outside the dot and on a change of the focused workspace (tickets 27, 52)
    BarElement {
        open: root.visible
        owners: [root.source]
        screenName: root.screen?.name ?? ""
        onClose: root.visible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.lg
        color: Theme.bar.menu.background

        ColumnLayout {
            id: list
            anchors.fill: parent
            anchors.margins: Theme.bar.menu.padding
            spacing: 0

            Repeater {
                model: Privacy.rows

                Item {
                    id: row
                    required property var modelData
                    readonly property string window: Privacy.windowOf(modelData, root.table, Apps.windows)
                    readonly property var tray: window === "" ? Privacy.trayOf(modelData, root.table) : null
                    readonly property bool usable: window !== "" || tray !== null

                    // a row of the tray menu: its height, padding, hover and dimmed look
                    Layout.fillWidth: true
                    implicitWidth: Math.max(Theme.bar.menu.minWidth, Math.ceil(label.implicitWidth))
                    implicitHeight: Theme.bar.menu.rowHeight
                    opacity: usable ? 1 : Theme.bar.menu.disabledOpacity

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius.sm
                        color: hover.hovered && row.usable ? Theme.bar.menu.hover : Theme.transparent
                    }

                    Text {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: Theme.bar.menu.rowPadding
                        rightPadding: Theme.bar.menu.rowPadding
                        text: Privacy.rowText(row.modelData)
                        font.family: Theme.font.family
                        font.pixelSize: Theme.font.sizeSmall
                        font.weight: Theme.font.weight
                        color: Theme.bar.menu.text
                    }

                    HoverHandler {
                        id: hover
                    }

                    TapHandler {
                        enabled: row.usable
                        onTapped: {
                            if (row.window !== "")
                                Apps.focusWindow(row.window);
                            else
                                Privacy.showFromTray(row.modelData, root.table);
                            root.visible = false;
                        }
                    }
                }
            }
        }
    }
}
