// Bar — one PanelWindow per screen, recreated on monitor hotplug by Variants.
// Adapted from serpantinum src/quickshell/bar/Bar.qml:
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// Copyright (C) 2026 Illia Miroshnichenko — AGPL-3.0-or-later
// Changes: kept only Variants + PanelWindow (no Config, autohide, redact, masks);
// size and layer match our Waybar; colour and size from Theme (ticket 05).
// One IpcHandler "bar" for all screens (serpantinum has one "topbar" handler per window).
// Ticket 07: transparent window with islands (ADR 0002); clock on the monitor's axis, workspaces to its right.
// Ticket 08a: left zone with the volume island. Ticket 08b: microphone island to its right.
// Ticket 09: BT island on the left edge; right zone with tray and Wi-Fi.
// Ticket 10: bell island on the right edge.
// Ticket 12: one Orbita per screen under the Wi-Fi / BT island; IpcHandler "orbit" opens it on the focused screen.
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.orbit
import qs.singletons.theme

Scope {
    id: root

    property bool shown: true

    signal orbitRequested(string tab, string screenName)

    // SUPER+H: qs -c ajmashell ipc call bar toggle (via ~/.config/hypr/scripts/shellset.sh hide)
    IpcHandler {
        target: "bar"

        function toggle(): void {
            root.shown = !root.shown;
        }
    }

    // qs -c ajmashell ipc call orbit toggle wifi|bt — for tests and, later, the Centrum sterowania rows (D4)
    IpcHandler {
        target: "orbit"

        function toggle(tab: string): void {
            root.orbitRequested(tab === "bt" ? "bt" : "wifi", Hyprland.focusedMonitor?.name ?? "");
        }
    }

    Variants {
        model: Quickshell.screens

        // qmltypes mark PanelWindow uncreatable; Quickshell substitutes the Wayland implementation at runtime
        PanelWindow { // qmllint disable uncreatable-type
            id: barWindow
            required property ShellScreen modelData

            screen: modelData
            visible: root.shown // hidden window also drops its exclusive zone, like Waybar on SIGUSR1

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: Theme.bar.height
            color: Theme.bar.background

            WlrLayershell.namespace: "ajmashell-bar"
            WlrLayershell.layer: WlrLayer.Bottom // like Waybar: fullscreen windows cover the bar

            Orbit {
                id: orbit
            }

            Connections {
                target: root

                function onOrbitRequested(tab: string, screenName: string): void {
                    if (screenName === barWindow.modelData.name)
                        orbit.toggle(tab === "bt" ? btIsland : wifiIsland, tab);
                }
            }

            // Left edge (ADR 0002 §3): BT · output volume · microphone.
            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.bar.edgePadding + Theme.bar.islandGap
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.bar.islandGap

                Bluetooth {
                    id: btIsland
                    orbitOpen: orbit.visible && orbit.source === btIsland
                    onClicked: orbit.toggle(btIsland, "bt")
                }

                Volume {}

                Volume {
                    microphone: true
                }
            }

            // Centre (ADR 0002 §3–4, changed 2026-09-29): media (ticket 17) · clock · workspaces.
            // The clock sits on the monitor's axis; neighbours hang off its sides, so their width never moves it.
            Clock {
                id: clock
                anchors.centerIn: parent
            }

            Workspaces {
                anchors.left: clock.right
                anchors.leftMargin: Theme.bar.islandGap
                anchors.verticalCenter: parent.verticalCenter
            }

            // Right edge (ADR 0002 §3): tray · Wi-Fi · bell (ticket 10). The tray hides while empty.
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.bar.edgePadding + Theme.bar.islandGap
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.bar.islandGap

                Tray {}

                Wifi {
                    id: wifiIsland
                    orbitOpen: orbit.visible && orbit.source === wifiIsland
                    onClicked: orbit.toggle(wifiIsland, "wifi")
                }

                Bell {}
            }
        }
    }
}
