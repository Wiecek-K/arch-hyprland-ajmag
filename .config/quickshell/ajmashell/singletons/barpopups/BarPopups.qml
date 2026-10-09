// Switching between the elements the Bar opens (ticket 27, user 2026-10-09): Orbita, audio popup, tray menu,
// media popup, Centrum sterowania. One click on another island closes the open element and opens the next one.
// How: each element's HyprlandFocusGrab has the Bar windows (`bars`) in `windows`, so a click on the Bar is no
// longer eaten by clearing the grab; the Bar reports every press (`press`) and each open element closes itself
// unless the press is on its own island (`closes`) — that island's toggle still closes it on a second click.
// A click beside the Bar and the element still clears the grab and only closes.
// Pure logic: bar/popups.mjs (tests tools/test-bar-popups.mjs). Own implementation.

pragma Singleton

import QtQuick
import Quickshell
import "../../bar/popups.mjs" as Logic

Singleton {
    id: root

    property list<QtObject> bars: [] // the Bar's PanelWindows on all screens (Bar.qml)

    signal pressed(var hit) // a press on a Bar; hit = the deepest item under the pointer

    function press(hit: var): void {
        pressed(hit);
    }

    // owner: the island the element hangs under, or a test on the hit item (see onBell)
    function closes(hit: var, owner: var): bool {
        return Logic.closesOn(hit, owner);
    }

    // true for a press on a bell (any Bar): the Centrum sterowania's own island
    function onBell(hit: var): bool {
        return Logic.findUp(hit, i => i.opensControl === true) !== null;
    }

    function deepestAt(item: Item, x: real, y: real): var {
        return Logic.deepestAt(item, x, y, (i, ix, iy) => i.childAt(ix, iy));
    }
}
