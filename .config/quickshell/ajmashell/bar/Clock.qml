// Clock island — format as in our Waybar clock module (Modules → "clock"): " 03:07 AM".
// A click opens the calendar popup (ticket 42).
// Own implementation; SystemClock with minute precision wakes the shell once a minute.

import QtQuick
import Quickshell
import qs.singletons.theme

Island {
    id: root

    onClicked: popup.toggle()

    function togglePopup(): void {
        popup.toggle();
    }

    // the popup followed the focus to this monitor (ticket 27)
    function openPopup(): void {
        popup.openPopup();
    }

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

    CalendarPopup {
        id: popup
        source: root
        now: clock.date
    }
}
