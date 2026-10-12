// NotificationPopups — the column of notification popups in the top-right corner of the focused
// monitor (like our swaync: positionX right, positionY top), below the Bar (ticket 10).
// Adapted from serpantinum src/quickshell/notifications/NotificationPopups.qml:
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// Copyright (C) 2026 Illia Miroshnichenko — AGPL-3.0-or-later
// Changes: fixed position top right (no Config presets, custom position, scaling or bar-position
// margins: ExclusionMode.Normal keeps the window below the Bar's exclusive zone, also when SUPER+H
// hides it); silent mode (DND) filters popups in Notifications.qml, not here; one card type (NotificationCard.qml) instead of the type Loader;
// window on the monitor focused when the first popup appears; timeout per notification from
// notifications.mjs; the timer restarts when a notification is replaced; sizes and colours from Theme.
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.singletons.notifications
import qs.singletons.theme

// qmltypes mark PanelWindow uncreatable; Quickshell substitutes the Wayland implementation at runtime
PanelWindow { // qmllint disable uncreatable-type
    id: root

    readonly property bool active: Notifications.popups.count > 0

    // Pinned when the first popup shows, so a focus change does not move the popups mid-read.
    function focusedScreen(): ShellScreen {
        return Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
    }

    onActiveChanged: if (active)
        screen = focusedScreen()
    screen: focusedScreen()
    visible: active

    anchors {
        top: true
        bottom: true
        right: true
    }

    // qmltypes do not resolve PanelWindow.margins (see the uncreatable-type note above); works at runtime
    margins { // qmllint disable unqualified unresolved-type
        top: Theme.notifications.marginTop
        right: Theme.notifications.marginRight
    }

    exclusionMode: ExclusionMode.Normal // respect the Bar's exclusive zone, reserve none
    exclusiveZone: 0
    focusable: false
    color: Theme.transparent // only the cards have a background
    implicitWidth: Theme.notifications.width

    WlrLayershell.namespace: "ajmashell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    // input only on the cards, the rest of the column clicks through
    mask: Region {
        item: list
    }

    ListView {
        id: list

        width: parent.width
        height: Math.min(parent.height, contentHeight)
        model: Notifications.popups
        spacing: Theme.notifications.spacing
        interactive: false

        add: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.notifications.appear
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "x"
                    from: Theme.notifications.width * Theme.notifications.slide
                    to: 0
                    duration: Theme.notifications.appear
                    easing.type: Easing.OutCubic
                }
            }
        }

        remove: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Theme.notifications.disappear
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "x"
                    to: Theme.notifications.width * Theme.notifications.slide
                    duration: Theme.notifications.disappear
                    easing.type: Easing.OutCubic
                }
            }
        }

        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: Theme.notifications.reflow
                easing.type: Easing.OutCubic
            }
        }

        delegate: NotificationCard {
            id: card

            required property int uid
            required property int timeout
            required property int generation

            width: ListView.view.width
            closable: true // ticket 37: hides the popup only, the notification stays in the Centrum
            closeOnIcon: true

            onClicked: Notifications.activate(uid, "")
            onCloseRequested: Notifications.removePopup(uid)
            onActionInvoked: identifier => Notifications.activate(uid, identifier)
            onGenerationChanged: dismissTimer.restart()

            Timer {
                id: dismissTimer
                interval: card.timeout
                running: card.timeout > 0 && !card.hovered
                onTriggered: Notifications.removePopup(card.uid)
            }
        }
    }
}
