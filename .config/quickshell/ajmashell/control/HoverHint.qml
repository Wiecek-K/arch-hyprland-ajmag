// HoverHint — a hint under (or above) a popup control after the pointer rests on it, in the Bar tooltip's style
// (bar/BarTooltip.qml, Theme.bar.tooltip). Used by the media popup (the keys of its controls, faza C ticket 29: long
// rest, Theme.media.keyHintDelay) and the eject button of the Sekcja Dyski (faza C ticket 06: above it, as the section
// sits at the screen's bottom edge; the Bar's short delay). Was media/KeyHint.qml until ticket 06; lives in qs.control
// because qs.media imports qs.control (the reverse would make the two modules import each other), and BarTooltip
// lives in qs.bar, which imports qs.media.
// Own implementation.

import QtQuick
import Quickshell
import qs.singletons.theme

PopupWindow {
    id: root

    required property Item target
    required property bool hovered
    required property int delay // ms of rest before it shows
    property string text
    property bool above: false

    anchor.item: target
    anchor.rect.x: 0
    anchor.rect.y: above ? -Theme.bar.tooltip.gap : 0
    anchor.rect.width: target.width
    anchor.rect.height: target.height + (above ? 0 : Theme.bar.tooltip.gap)
    // qmltypes give these as Edges::Flags, which qmllint cannot resolve
    anchor.edges: above ? Edges.Top : Edges.Bottom // qmllint disable missing-type
    anchor.gravity: above ? Edges.Top : Edges.Bottom // qmllint disable missing-type

    visible: timer.done && hovered && text !== ""
    implicitWidth: Math.ceil(label.implicitWidth) + 2 * Theme.bar.tooltip.padding
    implicitHeight: Math.ceil(label.implicitHeight) + 2 * Theme.bar.tooltip.padding
    color: Theme.transparent // only the rounded box below is drawn

    // shown after the rest, hidden at once; the timer runs only while hovered
    Timer {
        id: timer
        property bool done: false
        interval: root.delay
        running: root.hovered
        onTriggered: done = true
    }

    onHoveredChanged: timer.done = false

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
