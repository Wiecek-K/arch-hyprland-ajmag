// IconSlot — a Bar icon in a slot as wide as the widest icon it can show, so the island keeps
// its width when the state changes (moved from Volume.qml in ticket 09; also Wi-Fi and BT islands).
// Own implementation.

import QtQuick
import qs.singletons.theme
import "glyphs.mjs" as Glyphs

Text {
    id: root

    required property list<string> icons // every glyph this slot can show
    // Centre the drawn shape, not the advance box: Nerd Font glyphs sit off-centre in it
    // (the Wi-Fi icon was off the round island's centre, user 2026-10-01). Ink boxes from glyphs.mjs.
    property bool centred: false
    // optical correction on top of the measured centring, px right / down (Wi-Fi wedge)
    property int opticalOffsetX: 0
    property int opticalOffsetY: 0
    readonly property var offset: centred ? Glyphs.centringOffset(text, { pixelSize: font.pixelSize, width, height, ascent: metrics.ascent }) : { x: 0, y: 0 }

    anchors.verticalCenter: parent?.verticalCenter
    // centred: move the drawn shape's middle, not the line box's, onto the island's axis
    anchors.verticalCenterOffset: offset.y + opticalOffsetY
    // Nerd Font icons overhang their advance width, so measure the drawn shape too
    width: Math.ceil(Math.max(...icons.map(glyph => Math.max(metrics.advanceWidth(glyph), metrics.tightBoundingRect(glyph).width))))
    horizontalAlignment: Text.AlignLeft
    leftPadding: offset.x + opticalOffsetX
    font.family: Theme.font.family
    font.pixelSize: Theme.font.size
    font.weight: Theme.font.weight
    color: Theme.bar.text

    FontMetrics {
        id: metrics
        font: root.font
    }
}
