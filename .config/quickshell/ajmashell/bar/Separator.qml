// Separator — a glyph between two Bar islands, like Waybar's "custom/separator#dot-line" (~/.config/waybar/ModulesCustom:
// format U+E621, no island background) between the notification group and the audio modules.
// Between the volume islands and the BT / Wi-Fi / bell pill (user, 2026-10-07, ticket 17).
// Own implementation.

import QtQuick
import qs.singletons.theme

Text {
    anchors.verticalCenter: parent?.verticalCenter
    text: "\u{e621}"
    font.family: Theme.font.family
    font.pixelSize: Theme.font.size
    font.weight: Theme.font.weight
    color: Theme.bar.separator
}
