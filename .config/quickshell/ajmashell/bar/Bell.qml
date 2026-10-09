// Bell island — the number of notifications in the history on a badge over the bell (ticket 10),
// like our Waybar "custom/swaync" (count + bell, red dot while there are notifications).
// The count sits on a badge, not beside the bell, so the island keeps its width (no jumps).
// Right click toggles silent mode (DND): crossed-out bell, no popups except critical ones.
// Left click opens the Centrum sterowania (ticket 14, D1; wired in Bar.qml). Until then (ticket 10) it cleared
// the notifications; clearing is now in the Centrum.
// Own implementation; badge idea from end-4 modules/ii/bar/NotificationUnreadCount.qml:
// https://github.com/end-4/dots-hyprland/blob/239b532ec6084c3c4a0b55c4089663a25fbb2576/dots/.config/quickshell/ii/modules/ii/bar/NotificationUnreadCount.qml

import QtQuick
import qs.singletons.notifications
import qs.singletons.theme
import "../singletons/notifications/notifications.mjs" as Logic

Island {
    id: root

    circle: true
    readonly property bool opensControl: true // its press leaves the Centrum to the toggle (BarPopups, ticket 27)

    onRightClicked: Notifications.toggleSilent()

    IconSlot {
        id: bell

        icons: Logic.BELL_ICONS
        centred: true // alone in a round island
        text: Logic.bellIcon(Notifications.silent)

        Rectangle {
            readonly property string label: Logic.badgeText(Notifications.count)

            // from the slot's middle (= the bell's middle once centred): the crossed-out bell is wider
            x: bell.width / 2 + Theme.notifications.badgeOffsetX
            y: bell.height / 2 - Theme.notifications.badgeSize
            width: Math.max(Theme.notifications.badgeSize, badgeLabel.implicitWidth + 4)
            height: Theme.notifications.badgeSize
            radius: height / 2
            color: Theme.notifications.badge
            opacity: label === "" ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.motion.fast
                }
            }

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text: parent.label
                font.family: Theme.font.family
                font.pixelSize: Theme.notifications.badgeFontSize
                font.weight: Theme.font.weight
                color: Theme.notifications.badgeText
            }
        }
    }
}
