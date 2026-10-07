// MediaButton — ⏮ ⏯ ⏭ on the Bar's media island (ticket 17): an icon that turns to the accent under the pointer,
// in a slot as wide as its widest glyph (play / pause), so the island keeps its width.
// Own implementation.

import QtQuick
import qs.singletons.theme

Item {
    id: root

    required property list<string> icons
    property string text: icons[0]
    signal clicked

    anchors.verticalCenter: parent?.verticalCenter
    implicitWidth: slot.width
    implicitHeight: Theme.bar.islandHeight
    opacity: enabled ? 1 : Theme.orbit.dimmed

    IconSlot {
        id: slot
        icons: root.icons
        text: root.text
        color: hover.hovered && root.enabled ? Theme.media.buttonHover : Theme.media.text
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
