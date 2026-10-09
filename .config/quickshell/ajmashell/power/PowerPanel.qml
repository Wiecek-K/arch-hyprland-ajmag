// Panel zasilania (ticket 18, D10): replaces wlogout. Six actions in a row — Lock, Logout, Suspend, Hibernate,
// Reboot, Shutdown — with wlogout's commands and keys (l e u h r s run at once, as in wlogout); arrows / Tab move,
// Enter or Space runs the selected one, Esc or a click beside the box closes. An action logind answers "na" / "no"
// for (CanHibernate on this laptop) is dimmed and does nothing.
// Opened by SUPER+L (~/.config/hypr/scripts/power.sh; wlogout stays on SUPER+SHIFT+L) and the power button of the
// Centrum sterowania. IPC: qs -c ajmashell ipc call power toggle
// Test without running anything: AJMASHELL_POWER_DRYRUN=1 logs the command instead (throw-away instance).
// Own implementation after caelestia modules/session/Content.qml (idea only: one row of large icon buttons, the
// keyboard moving the selection, Enter runs):
// https://github.com/caelestia-dots/shell/blob/454f46da16ae75cc57f34adf48dea74db0fa5175/modules/session/Content.qml
// (GPL-3.0). Ours: wlogout's six actions and keys instead of caelestia's four, no GIF, a box in the screen centre
// like the launcher (not the screen edge), look background and flare of the big popups, Theme.power.
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.orbit
import qs.singletons.look
import qs.singletons.theme
import "power.mjs" as Logic
import "../launcher/launcher.mjs" as Launch

Scope {
    id: root

    property bool open: false
    property string screenName: ""
    property int current: 0 // selected button; Lock after every open, so Enter at once only locks
    property var answers: ({}) // logind's Can* answers, asked on every open
    readonly property var allowed: Logic.allowed(answers)

    readonly property bool dryRun: Quickshell.env("AJMASHELL_POWER_DRYRUN") === "1"
    readonly property var env: ({
            home: Quickshell.env("HOME"),
            sessionId: Quickshell.env("XDG_SESSION_ID") ?? ""
        })

    // empty name (IPC, keyboard): the monitor with the focus
    function toggle(name: string): void {
        if (open) {
            open = false;
            return;
        }
        screenName = name || (Hyprland.focusedMonitor?.name ?? "");
        current = 0;
        logind.running = true;
        open = true;
    }

    function run(index: int): void {
        const action = Logic.ACTIONS[index];
        if (!action || !allowed[index])
            return;
        open = false;
        const command = Logic.command(action, env);
        if (dryRun)
            console.log("power dry run:", JSON.stringify(command));
        else
            Hyprland.dispatch(Launch.execRequest(command, "")); // through Hyprland, as the launcher's apps
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            root.toggle("");
        }
    }

    Process {
        id: logind
        command: Logic.canCommand()
        stdout: StdioCollector {
            onStreamFinished: root.answers = Logic.parseCans(text)
        }
    }

    // Created once at startup and only hidden (as the launcher: no stall on open).
    LazyLoader {
        active: true

        // qmltypes mark PanelWindow uncreatable; Quickshell substitutes the Wayland implementation at runtime
        PanelWindow { // qmllint disable uncreatable-type
            id: win

            visible: root.open
            screen: Quickshell.screens.find(s => s.name === root.screenName) ?? null
            // only the box, Hyprland centres it (as the launcher: a full-screen surface redraws the whole screen
            // on every frame of the flare)
            implicitWidth: box.width
            implicitHeight: box.height
            color: Theme.transparent // the box has rounded corners
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "ajmashell-power"
            // OnDemand + focus grab, as the launcher: Exclusive would break the grab's click beside the box
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            onVisibleChanged: {
                // the grab refuses a window that is not mapped yet, so arm it after the window shows
                Qt.callLater(() => grab.active = win.visible);
                if (visible)
                    box.forceActiveFocus();
            }

            HyprlandFocusGrab {
                id: grab
                windows: [win]
                onCleared: root.open = false
            }

            ClippingRectangle {
                id: box

                width: buttons.width + 2 * Theme.power.padding
                height: buttons.height + 2 * Theme.power.padding
                radius: Theme.radius.lg
                color: Look.background(Theme.power)

                focus: true
                Keys.onPressed: event => {
                    const key = event.key;
                    if (key === Qt.Key_Escape)
                        root.open = false;
                    else if (key === Qt.Key_Left || key === Qt.Key_Up || key === Qt.Key_Backtab)
                        root.current = Logic.step(root.current, Logic.ACTIONS.length, -1, root.allowed);
                    else if (key === Qt.Key_Right || key === Qt.Key_Down || key === Qt.Key_Tab)
                        root.current = Logic.step(root.current, Logic.ACTIONS.length, 1, root.allowed);
                    else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space)
                        root.run(root.current);
                    else {
                        const action = Logic.actionForKey(event.text);
                        if (!action || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
                            return;
                        root.run(Logic.ACTIONS.indexOf(action));
                    }
                    event.accepted = true;
                }

                // looks with `flare`: the Orbita's lens flare behind the buttons; turns only in a look with motion
                OrbitBackdrop {
                    id: backdrop
                    anchors.fill: parent
                    visible: Look.current.flare

                    Timer {
                        interval: 1000 / Theme.orbit.fps
                        repeat: true
                        running: win.visible && backdrop.visible && Look.current.motion
                        onTriggered: backdrop.angle = (backdrop.angle + 2 * Math.PI * interval / Theme.orbit.period) % (2 * Math.PI)
                    }
                }

                Row {
                    id: buttons
                    x: Theme.power.padding
                    y: Theme.power.padding
                    spacing: Theme.power.spacing

                    Repeater {
                        model: Logic.ACTIONS

                        // colours of the Orbita's pills (Pill.qml): selected = the current tab, `softPills` = faint fill
                        Rectangle {
                            id: button

                            required property var modelData
                            required property int index
                            readonly property bool selected: root.current === index
                            readonly property bool soft: Look.current.softPills
                            readonly property color ink: soft ? (selected ? Theme.orbit.selected : Theme.power.text) : selected ? Theme.orbit.tabText : Theme.orbit.buttonText

                            width: Theme.power.button
                            height: Theme.power.button
                            radius: Theme.radius.lg
                            enabled: root.allowed[index]
                            opacity: enabled ? 1 : Theme.orbit.dimmed
                            color: soft ? (selected ? Qt.alpha(Theme.orbit.tab, Theme.orbit.softPill.active) : Qt.alpha(Theme.power.text, Theme.orbit.softPill.idle))
                                        : selected ? Theme.orbit.tab : Theme.orbit.button

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacing.sm

                                OrbitText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: button.modelData.icon
                                    font.pixelSize: Theme.power.iconSize
                                    color: button.ink
                                }

                                OrbitText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: button.modelData.label
                                    color: button.ink
                                }

                                // wlogout's key, so it can be learnt from the panel
                                OrbitText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: button.modelData.key.toUpperCase()
                                    font.pixelSize: Theme.font.sizeSmall
                                    color: button.ink
                                    opacity: Theme.orbit.dimmed
                                }
                            }

                            // the pointer selects, as the arrows do (a dimmed button stays unselectable)
                            HoverHandler {
                                enabled: button.enabled
                                onHoveredChanged: if (hovered) root.current = button.index
                            }

                            TapHandler {
                                enabled: button.enabled
                                onTapped: root.run(button.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
