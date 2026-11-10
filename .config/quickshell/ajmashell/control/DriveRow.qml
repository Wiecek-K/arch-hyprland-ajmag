// DriveRow — one removable drive in the Dyski section of the Centrum sterowania (faza C ticket 06): the drive's
// icon, its name and use (or the eject state) under it, the eject button at the right. A click on the rest of the
// row opens the drive in the file manager (only while something on it is mounted).
// Own implementation; the look of the Wi-Fi / BT rows (ConnectionRow.qml).

import QtQuick
import qs.orbit
import qs.singletons.theme

Rectangle {
    id: root

    property string title
    property string text
    property bool openable: false // something is mounted: the row opens it
    property bool ejecting: false
    property bool canEject: true // false while another drive is being ejected

    signal opened
    signal ejected

    readonly property bool ejectHot: ejectHover.hovered && canEject && !ejecting

    implicitHeight: Theme.control.rowHeight
    radius: height / 2
    color: rowHover.hovered && openable && !ejectHover.hovered ? Theme.control.hover : Theme.control.track

    HoverHandler {
        id: rowHover
    }

    // the eject button has its own TapHandler, but this one fires too: a tap on it must not open the drive
    TapHandler {
        enabled: root.openable
        onTapped: eventPoint => {
            const p = ejectButton.mapFromItem(root, eventPoint.position);
            if (!ejectButton.contains(p))
                root.opened();
        }
    }

    Item {
        id: icon

        x: Theme.spacing.sm
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - 2 * Theme.spacing.sm
        height: width

        Text {
            anchors.centerIn: parent
            text: "\u{f129e}" // md-usb_flash_drive
            font.family: Theme.font.family
            font.pixelSize: Theme.font.sizeLarge
            color: Theme.control.text
        }
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: Theme.spacing.lg
        anchors.right: ejectButton.left
        anchors.rightMargin: Theme.spacing.md
        anchors.verticalCenter: parent.verticalCenter

        OrbitText {
            width: parent.width
            text: root.title
        }

        OrbitText {
            width: parent.width
            text: root.ejecting ? "Ejecting…" : root.text
            font.pixelSize: Theme.font.sizeSmall
            color: Theme.control.subtext
        }
    }

    Rectangle {
        id: ejectButton

        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing.sm
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - 2 * Theme.spacing.sm
        height: width
        radius: width / 2
        color: root.ejectHot ? Theme.control.hover : Theme.transparent
        opacity: root.canEject || root.ejecting ? 1 : 0.4

        Text {
            anchors.centerIn: parent
            text: "\u{f01ea}" // md-eject
            font.family: Theme.font.family
            font.pixelSize: Theme.font.sizeLarge
            color: Theme.control.text
        }

        HoverHandler {
            id: ejectHover
        }

        TapHandler {
            enabled: root.canEject && !root.ejecting
            onTapped: root.ejected()
        }
    }
}
