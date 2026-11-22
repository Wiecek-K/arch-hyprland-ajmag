// StackEdges — the stack under a card in the Centrum powiadomień (ticket 32): edges of the next cards of a
// collapsed group in the spacing below the card, and the card's edge-coloured copy while it rises from the stack
// (StackMotion). Lies under the card, same size as the row's body. Split out of the row delegate in
// control/ControlCenter.qml (faza C ticket 03). Own implementation.

pragma ComponentBehavior: Bound

import QtQuick
import qs.notifications
import qs.singletons.theme
import "../singletons/notifications/notifications.mjs" as NotifLogic

Item {
    id: root

    required property Rectangle cardItem // the row's NotificationCard
    required property int edgeCount // edges shown (0 = none), NotifLogic.stackEdges
    required property bool rising // the card grows from the first edge: show its copy in the edge's colour

    // the card as an edge while it grows (StackMotion.rise); under the card, same place and size
    Rectangle {
        x: root.cardItem.x
        y: root.cardItem.y
        width: root.cardItem.width
        height: root.cardItem.height
        scale: root.cardItem.scale
        transformOrigin: Item.Bottom
        radius: root.cardItem.radius
        color: Theme.notifications.stack
        visible: root.rising
    }

    // each edge shows only its bottom strip: a card-sized rectangle clipped to stackPeek px
    Repeater {
        model: NotifLogic.STACK_MAX_EDGES

        Item {
            id: edge

            required property int index
            readonly property int inset: Theme.notifications.stackInset * (index + 1)

            x: inset
            y: root.cardItem.height + Theme.notifications.stackGap + (Theme.notifications.stackPeek + Theme.notifications.stackGap) * index
            width: root.width - 2 * inset
            height: Theme.notifications.stackPeek
            clip: true
            opacity: index >= root.edgeCount ? 0 : index === 0 ? 1 : Theme.notifications.stackFade

            Behavior on opacity {
                FadeFast {}
            }

            Rectangle {
                width: parent.width
                height: root.cardItem.height
                y: parent.height - height
                radius: root.cardItem.radius
                color: Theme.notifications.stack
            }
        }
    }
}
