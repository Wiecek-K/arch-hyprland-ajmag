// Holds Look's motion clock running while `active` (ticket 28): an open popup's flare or the Orbita's
// turning nodes. Counts itself in Look.clockUsers, so the clock stops when nothing that moves is shown.
// Own code, no donor.

import QtQuick
import qs.singletons.look

QtObject {
    id: user

    property bool active: false
    // whether this user is in Look.clockUsers now: each change adds or removes exactly once, whether or
    // not the binding's first value emits activeChanged (code review, ticket 28)
    property bool counted: false

    function sync(): void {
        if (active === counted)
            return;
        Look.clockUsers += active ? 1 : -1;
        counted = active;
    }

    onActiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (user.counted) Look.clockUsers -= 1
}
