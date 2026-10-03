// Clock island — format as in our Waybar clock module (Modules → "clock"): " 03:07 AM".
// No click action yet: a click will open the calendar popup (later ticket).
// Own implementation; SystemClock with minute precision wakes the shell once a minute.

import QtQuick
import Quickshell
import qs.singletons.theme

Island {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        text: " " + Qt.formatDateTime(clock.date, "hh:mm AP")
        font.family: Theme.font.family
        font.pixelSize: Theme.font.size
        font.weight: Theme.font.weight
        color: Theme.bar.text
    }
}
