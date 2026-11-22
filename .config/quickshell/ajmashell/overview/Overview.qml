// Overview of workspaces (faza C ticket cb44, B11 #11): SUPER+Tab → qs -c ajmashell ipc call overview toggle.
// A 2×5 grid of workspaces 1-10 (empty ones too) with live thumbnails of their windows, on the focused monitor
// only; windows of the other monitor are dimmed (user, 2026-11-12).
//   click on a workspace = go there; click on a window = focus it; both close the overview
//   drag a window onto another workspace = move it there (without following); middle click = close the window
//   drag a workspace's number onto another workspace = swap their contents (user's idea, 2026-10-01)
//   Esc, SUPER+Tab again or a click beside the box = close
// Adapted from end-4/dots-hyprland overview (OverviewWidget.qml, OverviewWindow.qml):
// https://github.com/end-4/dots-hyprland/blob/2f0c8bf/dots/.config/quickshell/ii/modules/ii/overview/
// Copyright (C) end-4 and contributors — GPL-3.0
// Changes: our window (created once and only hidden, as the launcher and Keybinds: OnDemand keyboard +
// HyprlandFocusGrab, the look's background, flare and shadow), style from Theme.overview instead of Appearance
// and Config, a fixed 2×5 grid, no search (the launcher lists windows), geometry and dispatches in overview.mjs
// (tested), the thumbnail dragged inside its delegate (no position timer), a window dropped on its own workspace
// goes back (no free placing of floating windows), the workspace number as a draggable badge for the swap,
// window data refreshed from Hyprland's events only while open.
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.look
import qs.singletons.apps
import qs.singletons.theme
import qs.singletons.look
import "overview.mjs" as Logic
import "../orbit" // OrbitBackdrop: the look's flare, as in the launcher

Scope {
    id: root

    property bool open: false

    // drag state shared by the thumbnails, the numbers and the workspaces' drop areas
    property int dragFrom: -1 // workspace of the dragged window or number
    property int dropTarget: -1 // workspace under the pointer while dragging

    IpcHandler {
        target: "overview"

        // closes when already open
        function toggle(): void {
            root.open = !root.open;
        }
    }

    function close(): void {
        open = false;
    }

    // the monitor the overview opened on: it stays there while open (focus moving to the other monitor does not move it)
    property string monitorName: ""

    onOpenChanged: if (open) {
        monitorName = Hyprland.focusedMonitor?.name ?? "";
        // lastIpcObject (position, size, floating, reserved band) is only as fresh as the last refresh
        Hyprland.refreshMonitors();
        Hyprland.refreshToplevels();
    }

    // every Hyprland event while open (window moved, opened, closed, floating…) → read the windows again
    Connections {
        target: Hyprland
        enabled: root.open
        function onRawEvent(event: HyprlandEvent): void {
            refresh.restart();
        }
    }

    Timer {
        id: refresh
        interval: Theme.motion.settle // one refresh for a burst of events (a swap moves many windows)
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshMonitors();
        }
    }

    readonly property var monitors: Hyprland.monitors.values.map(m => m.lastIpcObject)
    readonly property var monitorIpc: monitors.find(m => m.name === monitorName) ?? null

    // a Hyprland window as a plain object for overview.mjs; lastIpcObject is re-read on every refresh
    function windowData(t: HyprlandToplevel): var {
        const ipc = t.lastIpcObject;
        const appId = ipc.class || t.wayland?.appId || "";
        return {
            address: t.address.startsWith("0x") ? t.address : "0x" + t.address,
            workspace: t.workspace?.id ?? ipc.workspace?.id ?? 0,
            monitor: ipc.monitor ?? -1,
            at: ipc.at ?? [0, 0],
            size: ipc.size ?? [0, 0],
            floating: ipc.floating ?? false,
            fullscreen: (ipc.fullscreen ?? 0) > 0,
            icon: DesktopEntries.heuristicLookup(appId)?.icon ?? appId
        };
    }

    // every window on workspaces 1-10 (the swap plan reads it)
    readonly property var windows: Hyprland.toplevels.values.map(t => windowData(t)).filter(w => Logic.cellOf(w.workspace) !== null)

    // Created once at startup and only hidden when closed (as the launcher: no stall on open).
    LazyLoader {
        active: true

        // qmltypes mark PanelWindow uncreatable; Quickshell substitutes the Wayland implementation at runtime
        PanelWindow { // qmllint disable uncreatable-type
            id: win

            visible: root.open && root.monitorIpc !== null
            screen: Quickshell.screens.find(s => s.name === root.monitorName) ?? null
            // only the box plus the shadow's band (no anchors: Hyprland centres it), like Keybinds
            implicitWidth: box.width + 2 * Theme.shadow.margin
            implicitHeight: box.height + 2 * Theme.shadow.margin
            mask: Region {
                item: box
            }
            color: Theme.transparent // the box has rounded corners
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "ajmashell-overview"
            // OnDemand + focus grab, as the launcher (Exclusive breaks the grab)
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            // the monitor's area without the Bar (a cell is a scaled copy of it) and the whole monitor (the limit)
            readonly property var usable: root.monitorIpc ? Logic.usableArea(root.monitorIpc) : ({ x: 0, y: 0, width: 1, height: 1 })
            readonly property var wholeMonitor: root.monitorIpc ? Logic.usableArea(Object.assign({}, root.monitorIpc, { reserved: [0, 0, 0, 0] })) : usable
            readonly property real scale: Logic.fitScale(usable, wholeMonitor.width * Theme.overview.widthShare,
                wholeMonitor.height * Theme.overview.heightShare, Theme.overview.spacing)
            readonly property int cellWidth: Math.round(usable.width * scale)
            readonly property int cellHeight: Math.round(usable.height * scale)
            readonly property int currentWorkspace: Hyprland.monitors.values.find(m => m.name === root.monitorName)?.activeWorkspace?.id ?? -1

            function cellX(workspace: int): int {
                return (Logic.cellOf(workspace)?.col ?? 0) * (cellWidth + Theme.overview.spacing);
            }
            function cellY(workspace: int): int {
                return (Logic.cellOf(workspace)?.row ?? 0) * (cellHeight + Theme.overview.spacing);
            }

            onVisibleChanged: {
                // the grab refuses a window that is not mapped yet, so arm it after the window shows
                Qt.callLater(() => grab.active = win.visible);
                root.dragFrom = -1;
                root.dropTarget = -1;
                if (visible)
                    keys.forceActiveFocus();
            }

            HyprlandFocusGrab {
                id: grab
                windows: [win]
                onCleared: root.close()
            }

            LookShadow {
                target: box
                radius: Theme.overview.radius // box is a ClippingRectangle, not a Rectangle
            }

            ClippingRectangle {
                id: box
                x: Theme.shadow.margin
                y: Theme.shadow.margin
                width: grid.width + 2 * Theme.overview.padding
                height: grid.height + 2 * Theme.overview.padding
                radius: Theme.overview.radius
                color: Theme.transparent // LookBackground draws the look's background
                LookBackground {}
                border.width: Theme.overview.borderWidth
                border.color: Theme.overview.border

                // the look's lens flare behind the grid; turns only in a look with motion
                OrbitBackdrop {
                    visible: Look.current.flare
                    width: box.width
                    height: box.height
                    radius: 0 // the box clips its own corners
                    open: win.visible
                }

                Item {
                    id: keys
                    focus: true
                    Keys.onEscapePressed: root.close()
                }

                Item {
                    id: grid
                    x: Theme.overview.padding
                    y: Theme.overview.padding
                    width: Logic.COLUMNS * win.cellWidth + (Logic.COLUMNS - 1) * Theme.overview.spacing
                    height: Logic.ROWS * win.cellHeight + (Logic.ROWS - 1) * Theme.overview.spacing

                    // workspaces: click = go there; drop areas for windows and numbers
                    Repeater {
                        model: Logic.WORKSPACES

                        Rectangle {
                            id: cell
                            required property int modelData
                            readonly property bool dropHere: root.dropTarget === modelData && root.dragFrom !== modelData

                            x: win.cellX(modelData)
                            y: win.cellY(modelData)
                            width: win.cellWidth
                            height: win.cellHeight
                            radius: Theme.overview.cellRadius
                            color: dropHere ? Theme.overview.cellDrop : Theme.overview.cell

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    Hyprland.dispatch(Logic.focusWorkspaceRequest(cell.modelData));
                                    root.close();
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                keys: ["ajmashell-window", "ajmashell-workspace"]
                                onEntered: root.dropTarget = cell.modelData
                                onExited: if (root.dropTarget === cell.modelData)
                                    root.dropTarget = -1
                            }
                        }
                    }

                    // window thumbnails over their workspaces
                    Repeater {
                        model: Hyprland.toplevels // stable objects: a delegate keeps its window across refreshes

                        Item {
                            id: thumb
                            required property HyprlandToplevel modelData
                            readonly property var info: root.windowData(modelData)
                            readonly property var rect: Logic.windowRect(info, root.monitors, win.cellWidth, win.cellHeight)
                                ?? ({ x: 0, y: 0, width: win.cellWidth, height: win.cellHeight })
                            readonly property bool dragged: area.drag.active

                            visible: Logic.cellOf(info.workspace) !== null // special workspaces and 11+ are not in the grid
                            x: win.cellX(info.workspace) + rect.x
                            y: win.cellY(info.workspace) + rect.y
                            width: rect.width
                            height: rect.height
                            // floating over tiled, fullscreen over both (end-4), the dragged one over all
                            z: dragged ? 10 : (info.fullscreen ? 2 : info.floating ? 1 : 0)
                            opacity: info.monitor === root.monitorIpc?.id ? 1 : Theme.overview.otherMonitorOpacity

                            ClippingRectangle {
                                id: tile
                                width: thumb.width
                                height: thumb.height
                                radius: Theme.overview.windowRadius
                                color: Theme.overview.windowEmpty
                                border.width: Theme.overview.windowBorderWidth
                                border.color: Theme.overview.windowBorder

                                Drag.active: thumb.dragged
                                Drag.keys: ["ajmashell-window"]
                                Drag.hotSpot.x: area.mouseX
                                Drag.hotSpot.y: area.mouseY

                                Behavior on x {
                                    enabled: !thumb.dragged
                                    NumberAnimation {
                                        duration: Theme.motion.fast
                                    }
                                }
                                Behavior on y {
                                    enabled: !thumb.dragged
                                    NumberAnimation {
                                        duration: Theme.motion.fast
                                    }
                                }

                                // live only while the overview is shown
                                ScreencopyView {
                                    id: capture
                                    property bool paused: false // a moment without a source makes a new capture
                                    property int attempts: 0 // restarts since the last frame
                                    readonly property bool wanted: win.visible && thumb.visible

                                    // Hyprland ends the capture when the window's buffer changes size (a window moved
                                    // in or out of a workspace resizes the others there): "Ending recording due to
                                    // screencopy failure" in qs log, and Quickshell drops hasContent without `stopped`
                                    // (user's manual test 2026-11-12). Start it again, a few times while it gets no frame.
                                    function restart(): void {
                                        if (!wanted || attempts >= Theme.overview.captureAttempts)
                                            return;
                                        attempts++;
                                        paused = true;
                                        retry.restart();
                                    }

                                    anchors.fill: parent
                                    captureSource: wanted && !paused ? thumb.modelData.wayland : null
                                    live: true
                                    onHasContentChanged: {
                                        if (hasContent)
                                            attempts = 0;
                                        else
                                            restart();
                                    }
                                    onStopped: restart()
                                    onWantedChanged: attempts = 0

                                    Timer {
                                        id: retry
                                        interval: Theme.overview.captureRetry
                                        onTriggered: {
                                            capture.paused = false;
                                            check.restart();
                                        }
                                    }

                                    Timer {
                                        id: check
                                        interval: Theme.overview.captureCheck
                                        onTriggered: if (!capture.hasContent)
                                            capture.restart()
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: area.pressed ? Theme.overview.windowPressed
                                        : area.containsMouse ? Theme.overview.windowHover : Theme.transparent
                                }

                                IconImage {
                                    readonly property int size: Math.min(Theme.overview.iconSize,
                                        Math.round(Math.min(thumb.width, thumb.height) / 3))
                                    x: Theme.overview.badgeMargin
                                    y: thumb.height - height - Theme.overview.badgeMargin
                                    implicitSize: size
                                    source: Quickshell.iconPath(thumb.info.icon, "application-x-executable")
                                }
                            }

                            MouseArea {
                                id: area
                                anchors.fill: tile
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                drag.target: pressedButtons & Qt.LeftButton ? tile : null
                                property bool moved: false

                                drag.onActiveChanged: if (drag.active) {
                                    moved = true;
                                    root.dragFrom = thumb.info.workspace;
                                }
                                onPressed: moved = false
                                onReleased: mouse => {
                                    if (moved) {
                                        const target = root.dropTarget;
                                        root.dragFrom = -1;
                                        root.dropTarget = -1;
                                        tile.x = 0; // back into its place; a moved window comes back with its new workspace
                                        tile.y = 0;
                                        if (target > 0 && target !== thumb.info.workspace)
                                            Hyprland.dispatch(Logic.moveRequest(thumb.info.address, target));
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        Hyprland.dispatch(Logic.closeRequest(thumb.info.address));
                                    } else if (mouse.button === Qt.LeftButton) {
                                        Apps.focusWindow(thumb.info.address);
                                        root.close();
                                    }
                                }
                            }
                        }
                    }

                    // focused workspace's frame, over the thumbnails
                    Rectangle {
                        x: win.cellX(win.currentWorkspace)
                        y: win.cellY(win.currentWorkspace)
                        z: 20
                        visible: Logic.cellOf(win.currentWorkspace) !== null
                        width: win.cellWidth
                        height: win.cellHeight
                        radius: Theme.overview.cellRadius
                        color: Theme.transparent
                        border.width: Theme.overview.currentWidth
                        border.color: Theme.overview.current
                    }

                    // workspace numbers: drag one onto another workspace = swap the two; a click = go there
                    Repeater {
                        model: Logic.WORKSPACES

                        Item {
                            id: slot
                            required property int modelData

                            x: win.cellX(modelData) + Theme.overview.badgeMargin
                            y: win.cellY(modelData) + Theme.overview.badgeMargin
                            z: badgeArea.drag.active ? 40 : 30
                            width: Theme.overview.badgeSize
                            height: Theme.overview.badgeSize

                            Rectangle {
                                id: badge
                                width: slot.width
                                height: slot.height
                                radius: width / 2
                                color: Theme.overview.badge

                                Drag.active: badgeArea.drag.active
                                Drag.keys: ["ajmashell-workspace"]
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                Text {
                                    anchors.centerIn: parent
                                    text: slot.modelData
                                    color: Theme.overview.badgeText
                                    font.family: Theme.font.family
                                    font.weight: Theme.font.weight
                                    font.pixelSize: Theme.overview.badgeFontSize
                                }
                            }

                            MouseArea {
                                id: badgeArea
                                anchors.fill: badge
                                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                drag.target: badge
                                property bool moved: false

                                drag.onActiveChanged: if (drag.active) {
                                    moved = true;
                                    root.dragFrom = slot.modelData;
                                }
                                onPressed: moved = false
                                onReleased: {
                                    if (moved) {
                                        const target = root.dropTarget;
                                        root.dragFrom = -1;
                                        root.dropTarget = -1;
                                        badge.x = 0;
                                        badge.y = 0;
                                        if (target > 0)
                                            for (const request of Logic.swapPlan(root.windows, slot.modelData, target))
                                                Hyprland.dispatch(request);
                                    } else {
                                        Hyprland.dispatch(Logic.focusWorkspaceRequest(slot.modelData));
                                        root.close();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
