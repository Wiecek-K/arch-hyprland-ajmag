// ConnectionRow — Wiersz Wi-Fi / Bluetooth of the Centrum sterowania (D4, CONTEXT.md): full width, the leading
// icon switches the Moduł on or off, the rest of the row shows the connection's name and opens the Orbita.
// Own implementation; full-row toggles after caelestia's sidebar (B11 #09, idea only).

import QtQuick
import qs.orbit
import qs.singletons.theme

Rectangle {
    id: root

    property string icon
    property string title // "Wi-Fi" / "Bluetooth"
    property string text // connection name or state
    property bool active: false // Moduł switched on

    signal toggled
    signal opened

    implicitHeight: Theme.control.rowHeight
    radius: height / 2
    color: rowHover.hovered && !switchHover.hovered ? Theme.control.hover : Theme.control.track

    HoverHandler {
        id: rowHover
    }

    TapHandler {
        onTapped: root.opened()
    }

    Rectangle {
        id: moduleSwitch

        x: Theme.spacing.sm
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - 2 * Theme.spacing.sm
        height: width
        radius: width / 2
        color: root.active ? Theme.control.fill : switchHover.hovered ? Theme.control.hover : Theme.transparent

        Text {
            anchors.centerIn: parent
            text: root.icon
            font.family: Theme.font.family
            font.pixelSize: Theme.font.sizeLarge
            color: root.active ? Theme.control.fillText : Theme.control.text
        }

        HoverHandler {
            id: switchHover
        }

        TapHandler {
            onTapped: root.toggled()
        }
    }

    Column {
        anchors.left: moduleSwitch.right
        anchors.leftMargin: Theme.spacing.lg
        anchors.right: chevron.left
        anchors.rightMargin: Theme.spacing.md
        anchors.verticalCenter: parent.verticalCenter

        OrbitText {
            width: parent.width
            text: root.title
        }

        OrbitText {
            width: parent.width
            text: root.text
            font.pixelSize: Theme.font.sizeSmall
            color: Theme.control.subtext
        }
    }

    OrbitText {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing.lg
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{f0142}" // chevron right: opens the Orbita
        color: Theme.control.subtext
    }
}
