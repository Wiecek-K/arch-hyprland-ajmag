// IslandGroup — several round islands in one pill (user, 2026-10-05: BT · Wi-Fi · bell at the right edge).
// Each child keeps its own clicks, tooltip and ring; set `grouped: true` on it so only the pill is drawn.
// Own implementation.

import QtQuick
import qs.singletons.theme

Rectangle {
    default property alias content: row.data

    implicitWidth: row.implicitWidth + 2 * Theme.bar.islandPadding
    implicitHeight: Theme.bar.islandHeight
    radius: height / 2
    color: Theme.bar.island

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.bar.traySpacing // as close as the tray icons (user, 2026-10-05)
    }
}
