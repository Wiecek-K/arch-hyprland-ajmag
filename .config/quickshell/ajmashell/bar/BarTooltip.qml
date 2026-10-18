// BarTooltip — hint under a Bar island while the pointer rests on it, like Waybar's GTK tooltip
// (style/islands.css: dark background, inverse_surface text, rounded).
// A popup window, not a QtQuick.Controls ToolTip: the Bar window is only 42 px tall and would clip it.
// Target = an island (hover from Island.hovered) or any item with its own `hovered` (tray icons, ticket 09).
// Own implementation.

import QtQuick
import Quickshell
import qs.singletons.theme

PopupWindow {
    id: root

    required property Item target
    property bool hovered: (target as Island)?.hovered ?? false
    property string text

    anchor.item: target
    anchor.rect.x: 0
    anchor.rect.y: 0
    anchor.rect.width: target.width
    anchor.rect.height: target.height + Theme.bar.tooltip.gap
    // qmltypes give these as Edges::Flags, which qmllint cannot resolve
    anchor.edges: Edges.Bottom // qmllint disable missing-type
    anchor.gravity: Edges.Bottom // qmllint disable missing-type

    visible: delay.done && hovered && text !== ""
    implicitWidth: Math.ceil(label.implicitWidth) + 2 * Theme.bar.tooltip.padding
    implicitHeight: Math.ceil(label.implicitHeight) + 2 * Theme.bar.tooltip.padding
    color: Theme.transparent // only the rounded box below is drawn

    // Shown after a short rest, hidden at once; the timer runs only while hovered.
    Timer {
        id: delay
        property bool done: false
        interval: Theme.motion.tooltipDelay
        running: root.hovered
        onTriggered: done = true
    }

    onHoveredChanged: delay.done = false

    Rectangle {
        anchors.fill: parent
        radius: Math.min(height / 2, Theme.radius.lg)
        color: Theme.bar.tooltip.background

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            font.family: Theme.font.family
            font.pixelSize: Theme.font.sizeSmall
            font.weight: Theme.font.weight
            color: Theme.bar.tooltip.text
        }
    }
}
