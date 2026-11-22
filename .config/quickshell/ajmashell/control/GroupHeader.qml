// GroupHeader — header of one group in the Centrum powiadomień (ticket 16): app name, count and arrow (a click
// expands or collapses the group), "Clear" for the group. Drawn by the group's newest row, not by the ListView's
// section delegate, so it moves with the cards when one is removed (ticket 32). Split out of the row delegate in
// control/ControlCenter.qml (faza C ticket 03). Own implementation.

pragma ComponentBehavior: Bound

import QtQuick
import qs.orbit
import qs.singletons.theme
import "../singletons/notifications/notifications.mjs" as NotifLogic

Item {
    id: root

    required property string groupKey
    required property int count
    required property bool open // the group is expanded
    // only the newest row draws it; hidden while that row slides out and its group goes on (the next row takes over)
    required property bool newest
    required property bool leavesGroup

    signal toggleRequested
    signal clearRequested

    height: newest ? clear.height + Theme.spacing.md : 0
    visible: newest && !leavesGroup

    OrbitText {
        anchors.left: parent.left
        anchors.right: clear.left
        anchors.rightMargin: Theme.spacing.md
        anchors.verticalCenter: clear.verticalCenter
        elide: Text.ElideRight
        text: (root.count > 1 ? (root.open ? NotifLogic.GROUP_OPEN_ICON : NotifLogic.GROUP_CLOSED_ICON) + "  " : "")
              + root.groupKey + (root.count > 1 ? " (" + root.count + ")" : "")
        font.pixelSize: Theme.font.sizeSmall
        color: Theme.control.subtext
    }

    Pill {
        id: clear
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacing.sm
        text: "Clear"
        onClicked: root.clearRequested()
    }

    // Clear has its own TapHandler, but this one fires too: a tap on Clear does not expand
    TapHandler {
        enabled: root.count > 1
        onTapped: eventPoint => {
            const p = root.mapToItem(clear, eventPoint.position);
            if (!clear.contains(p))
                root.toggleRequested();
        }
    }
}
