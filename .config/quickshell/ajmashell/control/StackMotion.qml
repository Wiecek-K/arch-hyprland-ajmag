// StackMotion — how a card in the Centrum powiadomień takes the place of the removed card above it (ticket 32):
// rise() in a collapsed group (the card comes out from the stack: from the first edge's place and width to a full
// card, fading in over its edge-coloured copy in StackEdges), slideFrom(y) in an expanded one (the row has jumped
// into the removed row's place; the card moves up from where it was drawn). Split out of the row delegate in
// control/ControlCenter.qml (faza C ticket 03). Own implementation.

pragma ComponentBehavior: Bound

import QtQuick
import qs.singletons.theme

Item {
    id: root

    required property Rectangle cardItem // the row's NotificationCard (transformOrigin Bottom)

    readonly property bool running: riseAnim.running || slideAnim.running

    function rise(): void {
        riseAnim.restart();
    }

    // from = the card's y offset, relative to its place in the row, where it was drawn before the removal
    function slideFrom(from: real): void {
        slideAnim.from = from;
        slideAnim.restart();
    }

    NumberAnimation {
        id: slideAnim
        target: root.cardItem
        property: "y"
        to: 0
        duration: Theme.notifications.centrumReflow
        easing.type: Easing.OutCubic // as removeDisplaced: the rows below move with it
    }

    // starts as the first edge (narrower, bottom on the edge's bottom) and grows to a full card
    ParallelAnimation {
        id: riseAnim
        NumberAnimation {
            target: root.cardItem
            property: "y"
            from: Theme.notifications.stackGap + Theme.notifications.stackPeek
            to: 0
            duration: Theme.notifications.centrumReflow
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root.cardItem
            property: "scale"
            from: 1 - 2 * Theme.notifications.stackInset / Math.max(root.cardItem.width, 1)
            to: 1
            duration: Theme.notifications.centrumReflow
            easing.type: Easing.OutCubic
        }
        // the edge's colour turns into the card: the card fades in over its edge-coloured copy
        NumberAnimation {
            target: root.cardItem
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.notifications.centrumReflow
            easing.type: Easing.InOutQuad
        }
    }
}
