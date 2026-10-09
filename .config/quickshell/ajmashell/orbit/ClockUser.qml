// Holds Look's motion clock running while `active` (ticket 28): an open popup's flare or the Orbita's
// turning nodes. Counts itself in Look.clockUsers, so the clock stops when nothing that moves is shown.
// Own code, no donor.

import QtQuick
import qs.singletons.look

QtObject {
    property bool active: false

    onActiveChanged: Look.clockUsers += active ? 1 : -1
    // a binding's first value emits no change signal
    Component.onCompleted: if (active) Look.clockUsers += 1
    Component.onDestruction: if (active) Look.clockUsers -= 1
}
