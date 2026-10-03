// Workspaces island — one list shared by all monitors (ADR 0002 §9, Waybar `all-outputs`).
// Click focuses a workspace, wheel moves to the next / previous number 1–10, empty ones too (Lua dispatch).
// Inspired by serpantinum src/quickshell/bar/modules/workspaces/WorkspacesWidget.qml
// (occupied = workspace has toplevels, wheel accumulator) and DankMaterialShell
// Services/HyprlandService.qml (Lua dispatch, see workspaces.mjs):
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// https://github.com/AvengeMedia/DankMaterialShell@9dc5b2c5af7d18b7231f425fe0d8fa7243233109
// Own implementation; look and states from our Waybar (style/islands.css) via Theme.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import qs.singletons.theme
import "workspaces.mjs" as Logic
import "wheel.mjs" as Wheel

Island {
    id: root

    property real wheelRest: 0

    spacing: Theme.bar.workspace.spacing

    // Numbers and focused workspace as shown on the Bar, taken from Hyprland once its events settle
    // (set by the timer, not bound — a binding would show every in-between state):
    // - switching to a workspace on another monitor, Hyprland first reports that monitor's old
    //   workspace as focused (focusedmon event), a few ms later the new one (workspace event);
    // - leaving an empty workspace for a new one (8 → 9), Quickshell drops 8 at once but adds 9
    //   only after it re-reads the workspace list, so the island shrank and grew back.
    property var shownIds: []
    property int focusedId: 0

    function settle(): void {
        shownIds = Logic.shownIds(Hyprland.workspaces.values.map(w => w.id));
        focusedId = Hyprland.focusedWorkspace?.id ?? 0;
    }

    Component.onCompleted: settle()

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged(): void {
            settleTimer.restart();
        }
    }

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged(): void {
            settleTimer.restart();
        }
    }

    Timer {
        id: settleTimer
        interval: Theme.motion.settle
        onTriggered: root.settle()
    }

    onWheelMoved: delta => {
        const step = Wheel.wheel(wheelRest, delta);
        wheelRest = step.rest;
        const target = step.step ? Logic.scrollTarget(Hyprland.focusedWorkspace?.id ?? 0, step.step) : null;
        if (target)
            Hyprland.dispatch(Logic.focusRequest(target));
    }

    Repeater {
        model: root.shownIds

        // Size and positions never depend on the state, and are whole pixels:
        // otherwise the number jumps a few pixels when its workspace gets focus.
        Item {
            id: button

            required property int modelData
            readonly property HyprlandWorkspace workspace: Hyprland.workspaces.values.find(w => w.id === modelData) ?? null
            readonly property bool focused: root.focusedId === modelData
            readonly property bool occupied: (workspace?.toplevels.values.length ?? 0) > 0
            readonly property bool urgent: workspace?.urgent ?? false

            anchors.verticalCenter: parent?.verticalCenter
            implicitWidth: Math.ceil(label.implicitWidth) + 2 * Theme.bar.workspace.padding
            implicitHeight: Theme.bar.workspace.height

            // the focused one is a full circle (user, 2026-09-29), wider only if the number does not fit;
            // drawn under the number, sticks out of the button into the row spacing.
            // Fades in and out: switching to a workspace on another monitor, Hyprland first reports
            // that monitor's old workspace as focused (focusedmon, then workspace event); the fade
            // hides that blink.
            Rectangle {
                opacity: button.focused ? 1 : 0
                width: Math.max(button.height, button.width)
                height: button.height
                x: Math.round((button.width - width) / 2)
                radius: height / 2
                color: Theme.bar.workspace.activeBackground

                Behavior on opacity {
                    NumberAnimation { duration: Theme.motion.fast }
                }
            }

            Text {
                id: label
                x: Math.round((button.width - implicitWidth) / 2)
                y: Math.round((button.height - implicitHeight) / 2)
                text: button.modelData
                font.family: Theme.font.family
                font.pixelSize: Theme.bar.workspace.fontSize
                font.weight: button.occupied || button.focused ? Theme.font.weight : Font.Normal
                color: button.focused ? Theme.bar.workspace.activeText
                     : hover.hovered ? Theme.bar.workspace.hover
                     : button.urgent ? Theme.bar.workspace.urgent
                     : button.occupied ? Theme.bar.workspace.occupied
                     : Theme.bar.workspace.empty

                Behavior on color {
                    ColorAnimation { duration: Theme.motion.fast }
                }
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: Hyprland.dispatch(Logic.focusRequest(button.modelData))
            }
        }
    }
}
