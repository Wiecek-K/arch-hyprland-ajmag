// DriveRow — one removable drive in the Sekcja Dyski of the Centrum sterowania (faza C ticket 06): the drive's
// icon, its name and use (or what is going on) under it, the eject button at the right with a hint above it. A click
// on the rest of the row asks the section to act (open the drive, or mount it first; DriveSection.activate).
// Own implementation; the look of the Wi-Fi / BT rows (ConnectionRow.qml).

import QtQuick
import qs.orbit
import qs.singletons.theme

Rectangle {
    id: root

    property string title
    property string text
    property bool clickable: false // the row opens or mounts the drive
    property string busy: "" // "Ejecting…" / "Mounting…" while that runs on this drive
    property bool canEject: true // false while an eject or a mount runs

    signal activated
    signal ejected

    readonly property bool ejectHot: ejectHover.hovered && canEject

    implicitHeight: Theme.control.rowHeight
    radius: height / 2
    color: rowHover.hovered && clickable && !ejectHover.hovered ? Theme.control.hover : Theme.control.track

    HoverHandler {
        id: rowHover
    }

    // the eject button has its own TapHandler, but this one fires too: a tap on it must not act on the row.
    // Every tap of a double click comes here (the second one opens a drive the first one is mounting)
    TapHandler {
        enabled: root.clickable
        onTapped: eventPoint => {
            const p = ejectButton.mapFromItem(root, eventPoint.position);
            if (!ejectButton.contains(p))
                root.activated();
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
            text: root.busy || root.text
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
        opacity: root.canEject || root.busy !== "" ? 1 : Theme.orbit.dimmed // as a disabled Pill

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
            enabled: root.canEject
            onTapped: root.ejected()
        }

        // above: the section sits at the screen's bottom edge (user 2026-11-10: a tooltip on this button)
        HoverHint {
            target: ejectButton
            hovered: ejectHover.hovered
            delay: Theme.motion.tooltipDelay
            above: true
            text: "Safely eject"
        }
    }
}
