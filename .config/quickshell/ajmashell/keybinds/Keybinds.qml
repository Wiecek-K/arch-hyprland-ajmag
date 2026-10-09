// Keybinds (ticket 20, B11 #07): a read-only list of the Hyprland key bindings with their descriptions and a search.
// SUPER+K → qs -c ajmashell ipc call keybinds toggle; also "Keybinds" in the launcher's app list
// (~/.local/share/applications/ajmashell-keybinds.desktop). Not a launcher mode and not its layout (user, 2026-10-03).
// Idea from omarchy's keybindings menu (MIT, idea only — row form in keybinds.mjs):
// https://github.com/basecamp/omarchy/blob/fd961e5/bin/omarchy-menu-keybindings
// Own: the window (created once and only hidden, as the launcher), the look's background and flare, Theme.keybinds.
// The binds are read anew on every open (`hyprctl binds -j`), so a Hyprland reload shows at once.
// A row does not run its bind (user, 2026-10-09; clickable list parked — ticket 20 lists the problems).
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.singletons.theme
import qs.singletons.look
import "keybinds.mjs" as Logic
import "../orbit" // OrbitBackdrop: the look's flare, as in the launcher

Scope {
    id: root

    property bool open: false
    property var rows: [] // Logic.rows of the last read

    IpcHandler {
        target: "keybinds"

        // closes when already open
        function toggle(): void {
            root.open = !root.open;
        }
    }

    onOpenChanged: if (open) binds.running = true

    Process {
        id: binds
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.rows = Logic.parse(text)
        }
    }

    // Created once at startup and only hidden when closed (as the launcher: no stall on open).
    LazyLoader {
        active: true

        // qmltypes mark PanelWindow uncreatable; Quickshell substitutes the Wayland implementation at runtime
        PanelWindow { // qmllint disable uncreatable-type
            id: win

            visible: root.open
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
            // only the box (no anchors: Hyprland centres it), like the launcher — a full-screen surface
            // would send the whole screen as changed on every frame of the flare
            implicitWidth: box.width
            implicitHeight: box.height
            color: Theme.transparent // the box has rounded corners
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "ajmashell-keybinds"
            // OnDemand + focus grab, as the launcher (Exclusive breaks the grab)
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            readonly property var shown: Logic.filter(root.rows, search.text)
            readonly property int chordWidth: Logic.chordWidth(root.rows) // over all rows: the column does not move while searching

            // arrows, Page Up/Down, Home/End: scroll by rows
            function scroll(delta: int): void {
                const top = Math.round(list.contentY / Theme.keybinds.rowHeight);
                list.contentY = Logic.step(top, shown.length, Theme.keybinds.rows, delta) * Theme.keybinds.rowHeight;
            }

            onShownChanged: list.contentY = 0
            onVisibleChanged: {
                // the grab refuses a window that is not mapped yet, so arm it after the window shows
                Qt.callLater(() => grab.active = win.visible);
                if (!visible)
                    return;
                search.text = "";
                list.contentY = 0;
                search.forceActiveFocus();
            }

            HyprlandFocusGrab {
                id: grab
                windows: [win]
                onCleared: root.open = false
            }

            ClippingRectangle {
                id: box
                width: Theme.keybinds.width
                height: field.height + Theme.keybinds.padding + Theme.keybinds.rows * Theme.keybinds.rowHeight + 2 * Theme.keybinds.padding
                radius: Theme.keybinds.radius
                color: Look.background(Theme.keybinds)
                border.width: Theme.keybinds.borderWidth
                border.color: Theme.keybinds.border

                // the look's lens flare behind the list; turns only in a look with motion
                OrbitBackdrop {
                    id: backdrop
                    visible: Look.current.flare
                    width: box.width
                    height: box.height
                    radius: 0 // the box clips its own corners

                    Timer {
                        interval: 1000 / Theme.orbit.fps
                        repeat: true
                        running: win.visible && backdrop.visible && Look.current.motion
                        onTriggered: backdrop.angle = (backdrop.angle + 2 * Math.PI * interval / Theme.orbit.period) % (2 * Math.PI)
                    }
                }

                Rectangle {
                    id: field
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.keybinds.padding
                    height: search.implicitHeight + 2 * Theme.keybinds.fieldPadding
                    radius: Theme.keybinds.fieldRadius
                    color: Theme.keybinds.field

                    Text {
                        id: searchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.keybinds.fieldPadding
                        anchors.verticalCenter: parent.verticalCenter
                        text: "" // nf-fa-search, as the launcher
                        color: Theme.keybinds.text
                        font: search.font
                    }

                    TextInput {
                        id: search
                        anchors.left: searchIcon.right
                        anchors.leftMargin: Theme.keybinds.fieldSpacing
                        anchors.right: count.left
                        anchors.rightMargin: Theme.keybinds.fieldSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.keybinds.text
                        selectionColor: Theme.keybinds.chord
                        selectedTextColor: Theme.keybinds.field
                        font.family: Theme.font.family
                        font.weight: Theme.keybinds.fontWeight
                        font.pixelSize: Theme.keybinds.fontSize
                        clip: true
                        focus: true

                        Keys.onEscapePressed: root.open = false
                        Keys.onReturnPressed: root.open = false
                        Keys.onEnterPressed: root.open = false
                        Keys.onUpPressed: win.scroll(-1)
                        Keys.onDownPressed: win.scroll(1)
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_PageUp)
                                win.scroll(-Theme.keybinds.rows);
                            else if (event.key === Qt.Key_PageDown)
                                win.scroll(Theme.keybinds.rows);
                            else
                                return;
                            event.accepted = true;
                        }

                        Text {
                            visible: !search.text
                            text: "Search keybinds"
                            color: Theme.keybinds.placeholder
                            font: search.font
                        }
                    }

                    // shown / all, so an empty search result is not mistaken for a broken list
                    Text {
                        id: count
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.keybinds.fieldPadding
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.shown.length + " / " + root.rows.length
                        color: Theme.keybinds.subtext
                        font: search.font
                    }
                }

                ListView {
                    id: list
                    x: Theme.keybinds.padding
                    y: field.y + field.height + Theme.keybinds.padding
                    width: box.width - 2 * Theme.keybinds.padding
                    height: Theme.keybinds.rows * Theme.keybinds.rowHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.shown

                    delegate: Row {
                        id: row
                        required property var modelData

                        height: Theme.keybinds.rowHeight
                        width: ListView.view.width

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Logic.pad(row.modelData.chord, win.chordWidth) + "  "
                            color: Theme.keybinds.chord
                            font: search.font
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: row.width - x
                            text: "→ " + row.modelData.description
                            elide: Text.ElideRight
                            color: Theme.keybinds.text
                            font: search.font
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: win.shown.length === 0
                        text: root.rows.length ? "No matching keybinds" : "No keybinds"
                        color: Theme.keybinds.subtext
                        font: search.font
                    }
                }
            }
        }
    }
}
