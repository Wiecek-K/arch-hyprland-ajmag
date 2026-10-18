// BarElement — how an element the Bar opens (Orbita, audio popup, tray menu, media popup, calendar, Centrum
// sterowania) closes (tickets 27, 52, see BarPopups.qml):
// - a press on the Bar outside its own islands closes it (`close`); its grab lets Bar clicks through, so the island
//   under the press opens its own element in the same click;
// - a change of the focused workspace closes it (ticket 52, user 2026-10-16), unless `stays`.
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
    // not closed by a focus change: the Orbita in the middle of an action (connecting, disconnecting, pairing,
    // asking for a password or a pairing code; user, 2026-10-16)
    property bool stays: false
    property int home: 0 // the active workspace of its monitor when it opened

    signal close

    function remember(): void {
        home = BarPopups.activeWorkspace(screenName);
    }

    onOpenChanged: {
        BarPopups.openCount += open ? 1 : -1;
        if (open)
            remember();
    }
    // a popup gets its screen from the anchor while it opens; the Centrum moves to another bell's screen
    onScreenNameChanged: {
        if (open)
            remember();
    }
    Component.onCompleted: {
        if (open) {
            BarPopups.openCount += 1;
            remember();
        }
    }
    Component.onDestruction: {
        if (open)
            BarPopups.openCount -= 1;
    }

    Connections {
        target: BarPopups

        function onEscaped(): void {
            if (root.open)
                root.close();
        }

        function onPressed(hit: var): void {
            if (root.open && Logic.closesOn(hit, root.owners))
                root.close();
        }

        function onFocusSettled(workspace: int): void {
            if (Logic.closesOnFocus(root.open, root.stays, root.home, workspace))
                root.close();
        }
    }
}
