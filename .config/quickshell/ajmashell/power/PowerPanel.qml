// Panel zasilania (ticket 18, D10): replaces wlogout. Like wlogout it covers the whole monitor with a translucent,
// blurred backdrop (our colours) and a row of large buttons in the middle: Lock, Logout, Suspend, Reboot, Shutdown,
// with wlogout's commands and keys (l e u r s run at once, as in wlogout). No Hibernate: the kernel has it off here
// (user, 2026-10-09: remove the button). Arrows / Tab move, Enter or Space runs the selected one; Esc or a click
// on the backdrop closes.
// Opened by SUPER+L (~/.config/hypr/scripts/power.sh; wlogout stays on SUPER+SHIFT+L) and the power button of the
// Centrum sterowania. IPC: qs -c ajmashell ipc call power toggle
// Test without running anything: AJMASHELL_POWER_DRYRUN=1 logs the command instead (throw-away instance).
// Own implementation after caelestia modules/session/Content.qml (idea only: large icon buttons, the keyboard
// moving the selection, Enter runs):
// https://github.com/caelestia-dots/shell/blob/454f46da16ae75cc57f34adf48dea74db0fa5175/modules/session/Content.qml
// (GPL-3.0). Ours: wlogout's actions and keys and its full-screen backdrop, no GIF, Theme.power colours, the
// look's flare standing still behind the buttons.
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
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
        open = true;
    }

    function run(index: int): void {
        const action = Logic.ACTIONS[index];
        if (!action)
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

    // Created once at startup and only hidden (as the launcher: no stall on open).
    LazyLoader {
        active: true

        // qmltypes mark PanelWindow uncreatable; Quickshell substitutes the Wayland implementation at runtime
        PanelWindow { // qmllint disable uncreatable-type
            id: win

            visible: root.open
            screen: Quickshell.screens.find(s => s.name === root.screenName) ?? null
            // the whole monitor, over the Bar, as wlogout (user, 2026-10-09)
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: Theme.transparent // the backdrop below draws the colour
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "ajmashell-power"
            // OnDemand + focus grab, as the launcher: the grab closes the panel on a click on another monitor
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            onVisibleChanged: {
                // the grab refuses a window that is not mapped yet, so arm it after the window shows
                Qt.callLater(() => grab.active = win.visible);
                if (visible)
                    backdrop.forceActiveFocus();
            }

            HyprlandFocusGrab {
                id: grab
                windows: [win]
                onCleared: root.open = false
            }

            // translucent and blurred in every look (rules.lua layerrule-10): a full-screen opaque colour would
            // hide the desktop, unlike wlogout
            Rectangle {
                id: backdrop
                anchors.fill: parent
                color: Theme.power.backdrop

                focus: true
                Keys.onPressed: event => {
                    const key = event.key;
                    if (key === Qt.Key_Escape)
                        root.open = false;
                    else if (key === Qt.Key_Left || key === Qt.Key_Up || key === Qt.Key_Backtab)
                        root.current = Logic.step(root.current, Logic.ACTIONS.length, -1);
                    else if (key === Qt.Key_Right || key === Qt.Key_Down || key === Qt.Key_Tab)
                        root.current = Logic.step(root.current, Logic.ACTIONS.length, 1);
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

                // a click on the backdrop closes; nested TapHandlers both fire, so skip clicks on the buttons
                TapHandler {
                    onTapped: point => {
                        const p = buttons.mapFromItem(backdrop, point.position.x, point.position.y);
                        if (!buttons.contains(p))
                            root.open = false;
                    }
                }

                // looks with `flare`: the Orbita's lens flare over the whole monitor, standing still — turning it
                // would redraw the whole monitor 30 times a second (ticket 13, B12)
                OrbitBackdrop {
                    anchors.fill: parent
                    radius: 0
                    visible: Look.current.flare
                }

                Row {
                    id: buttons
                    anchors.centerIn: parent
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
                            radius: Theme.power.radius
                            color: soft ? (selected ? Qt.alpha(Theme.orbit.tab, Theme.orbit.softPill.active) : Qt.alpha(Theme.power.text, Theme.orbit.softPill.idle))
                                        : selected ? Theme.orbit.tab : Theme.orbit.button

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacing.md

                                OrbitText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: button.modelData.icon
                                    font.pixelSize: Theme.power.iconSize
                                    color: button.ink
                                }

                                OrbitText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: button.modelData.label
                                    font.pixelSize: Theme.font.sizeLarge
                                    color: button.ink
                                }

                                // wlogout's key, so it can be learnt from the panel
                                OrbitText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: button.modelData.key.toUpperCase()
                                    color: button.ink
                                    opacity: Theme.orbit.dimmed
                                }
                            }

                            // the pointer selects, as the arrows do
                            HoverHandler {
                                onHoveredChanged: if (hovered) root.current = button.index
                            }

                            TapHandler {
                                onTapped: root.run(button.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
