// BarElement — how an element the Bar opens (Orbita, audio popup, tray menu, media popup, Centrum sterowania)
// moves between Bar islands and monitors (ticket 27, see BarPopups.qml):
// - a press on the Bar outside its own islands closes it (`close`); its grab lets Bar clicks through, so the island
//   under the press opens its own element in the same click;
// - while open it follows the focused monitor (`follow`, user 2026-10-10), unless `stays`.
// Own implementation.

import QtQuick
import Quickshell
import qs.singletons.barpopups
import "popups.mjs" as Logic

Scope {
    id: root

    required property bool open // the element is shown
    required property var owners // its own islands (list of Items), or a test on the hit item (Logic.onBell)
    required property string screenName // the monitor it is on now
    property bool stays: false // held on its monitor (the Orbita while pairing or asking for a password)

    signal close
    signal follow(string screenName) // the focused monitor changed: show the element there

    Connections {
        target: BarPopups

        function onPressed(hit: var): void {
            if (root.open && Logic.closesOn(hit, root.owners))
                root.close();
        }

        function onFocusedScreenChanged(): void {
            const to = Logic.followTarget(root.open, root.stays, root.screenName, BarPopups.focusedScreen);
            if (to !== "")
                root.follow(to);
        }
    }
}
