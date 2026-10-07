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
// Ticket 14: the bell asks for the Centrum sterowania (controlRequested, handled in shell.qml); its rows open the Orbita.
// Ticket 17: media island left of the clock; IpcHandler "media" opens its popup on the focused screen.
// Tray and volume islands swapped (user, 2026-10-07): tray on the left edge, volume · microphone · separator before the pill.
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
    signal controlRequested(string screenName)
    signal mediaRequested(string screenName)

    // SUPER+H: qs -c ajmashell ipc call bar toggle (via ~/.config/hypr/scripts/shellset.sh hide)
    IpcHandler {
        target: "bar"

        function toggle(): void {
            root.shown = !root.shown;
        }
    }

    // qs -c ajmashell ipc call orbit toggle wifi|bt — for tests; the Centrum sterowania rows (D4) emit orbitRequested directly
    IpcHandler {
        target: "orbit"

        function toggle(tab: string): void {
            root.orbitRequested(tab === "bt" ? "bt" : "wifi", Hyprland.focusedMonitor?.name ?? "");
        }
    }

    // qs -c ajmashell ipc call media toggle — the media popup on the focused screen (tests; the Bar opens it by a click)
    IpcHandler {
        target: "media"

        function toggle(): void {
            root.mediaRequested(Hyprland.focusedMonitor?.name ?? "");
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
            // Top, not Bottom (ticket 13, research B12): a commit from a surface below Top, or from its popup
            // (the Orbita), marks Hyprland's background blur stale and redraws the whole monitor every frame.
            // Fullscreen windows still cover a Top layer; floating windows no longer do.
            WlrLayershell.layer: WlrLayer.Top

            Orbit {
                id: orbit
            }

            Connections {
                target: root

                function onOrbitRequested(tab: string, screenName: string): void {
                    if (screenName === barWindow.modelData.name)
                        orbit.toggle(tab === "bt" ? btIsland : wifiIsland, tab);
                }

                function onMediaRequested(screenName: string): void {
                    if (screenName === barWindow.modelData.name)
                        mediaIsland.togglePopup();
                }
            }

            // Left edge (ADR 0002 §3, changed 2026-10-07): tray. It hides while empty.
            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.bar.edgePadding + Theme.bar.islandGap
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.bar.islandGap

                Tray {}
            }

            // Centre (ADR 0002 §3–4, changed 2026-09-29): media (ticket 17) · clock · workspaces.
            // The clock sits on the monitor's axis; neighbours hang off its sides, so their width never moves it.
            MediaIsland {
                id: mediaIsland
                anchors.right: clock.left
                anchors.rightMargin: Math.round(clock.width * Theme.media.clockGap) // user, 2026-10-07: further from the clock
                anchors.verticalCenter: parent.verticalCenter
            }

            Clock {
                id: clock
                anchors.centerIn: parent
            }

            Workspaces {
                anchors.left: clock.right
                anchors.leftMargin: Theme.bar.islandGap
                anchors.verticalCenter: parent.verticalCenter
            }

            // Right edge (ADR 0002 §3, changed 2026-10-07): output volume · microphone · separator (Waybar dot-line)
            // · one pill with BT · Wi-Fi · bell (user, 2026-10-05).
            // The tray hides while empty.
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.bar.edgePadding + Theme.bar.islandGap
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.bar.islandGap

                Volume {}

                Volume {
                    microphone: true
                }

                Separator {}

                IslandGroup {
                    Bluetooth {
                        id: btIsland
                        grouped: true
                        orbitOpen: orbit.visible && orbit.source === btIsland
                        onClicked: orbit.toggle(btIsland, "bt")
                    }

                    Wifi {
                        id: wifiIsland
                        grouped: true
                        orbitOpen: orbit.visible && orbit.source === wifiIsland
                        onClicked: orbit.toggle(wifiIsland, "wifi")
                    }

                    Bell {
                        grouped: true
                        onClicked: root.controlRequested(barWindow.modelData.name)
                    }
                }
            }
        }
    }
}
