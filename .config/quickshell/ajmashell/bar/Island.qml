// Island — one Bar element in its own fully rounded container (ADR 0002 §1–2),
// like a Waybar module in style/islands.css. Children go into a centred Row.
// Own implementation.

import QtQuick
import qs.singletons.theme

Rectangle {
    id: root

    default property alias content: row.data
    property alias spacing: row.spacing
    readonly property alias hovered: hover.hovered
    property bool circle: false // icon-only island: width = height (BT, Wi-Fi; user, 2026-10-01)
    // State ring along the inside of the edge, Theme.bar.ringWidth wide; the island's own colour
    // stays in the middle (BT connected; user, 2026-10-01). Fully transparent = not drawn.
    property color ring: Theme.transparent

    // on the whole island, padding included (like a Waybar module)
    signal clicked
    signal rightClicked
    signal wheelMoved(real delta)

    implicitWidth: circle ? implicitHeight : row.implicitWidth + 2 * Theme.bar.islandPadding
    implicitHeight: Theme.bar.islandHeight
    radius: height / 2
    color: Theme.bar.island

    Rectangle {
        anchors.fill: parent
        visible: root.ring.a > 0
        radius: height / 2
        color: Theme.transparent // only the ring is drawn
        border.width: Theme.bar.ringWidth
        border.color: root.ring

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.motion.fast
            }
        }
    }

    // MouseArea, not WheelHandler: on the Bar's layer-shell window WheelHandler gets no wheel
    // events (checked 2026-09-29 with a virtual uinput mouse). Below the Row, so the content's
    // own handlers (workspace buttons) still get clicks and hover.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => root.wheelMoved(wheel.angleDelta.y)
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (eventPoint, button) => button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }

    Row {
        id: row
        anchors.centerIn: parent
    }
}
