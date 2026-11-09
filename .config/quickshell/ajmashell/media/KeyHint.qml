// KeyHint — the key of a media popup control, shown under it after a long rest of the pointer (faza C ticket 29,
// user 2026-11-09: "tooltip na przyciskach ale po jakimś dłuższym hoverze"). Looks like the Bar's tooltip
// (bar/BarTooltip.qml, same Theme.bar.tooltip style), but its own file: BarTooltip lives in qs.bar, which imports
// qs.media, so using it here would make the two modules import each other.
// Own implementation.

import QtQuick
import Quickshell
import qs.singletons.theme

PopupWindow {
    id: root

    required property Item target
    required property bool hovered
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

    // shown after a long rest, hidden at once; the timer runs only while hovered
    Timer {
        id: delay
        property bool done: false
        interval: Theme.media.keyHintDelay
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
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.font.family
            font.pixelSize: Theme.font.sizeSmall
            font.weight: Theme.font.weight
            color: Theme.bar.tooltip.text
        }
    }
}
