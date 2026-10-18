// OrbitText — text in the Orbita's font and colour; also used by the audio popup and the Centrum sterowania (ticket 14).
// Own implementation (was an inline component of Orbit.qml until ticket 14).

import QtQuick
import qs.singletons.theme

Text {
    font.family: Theme.font.family
    font.pixelSize: Theme.font.size
    font.weight: Theme.font.weight
    color: Theme.orbit.text
    elide: Text.ElideRight
}
