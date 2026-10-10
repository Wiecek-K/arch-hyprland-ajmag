// Switching between the elements the Bar opens (ticket 27, user 2026-10-09): Orbita, audio popup, tray menu,
// media popup, Centrum sterowania. One click on another island closes the open element and opens the next one.
// How: each element's HyprlandFocusGrab has the Bar windows (`bars`) in `windows`, so a click on the Bar is no
// longer eaten by clearing the grab; the Bar reports every press (`press`) and each open element closes itself
// through its BarPressCloser unless the press is on one of its own islands — that island's toggle still closes
// it on a second click. A click beside the Bar and the element still clears the grab and only closes.
// Pure logic: popups.mjs (tests tools/test-bar-popups.mjs). Own implementation.

pragma Singleton

import QtQuick
import Quickshell
import "popups.mjs" as Logic

Singleton {
    id: root

    property list<QtObject> bars: [] // the Bar's PanelWindows on all screens (Bar.qml)

    signal pressed(var hit) // a press on a Bar; hit = the deepest item under the pointer, null = none

    // a press at (x, y) in `content`, the Bar's item holding every island
    function press(content: Item, x: real, y: real): void {
        pressed(Logic.deepestAt(content, x, y, (item, ix, iy) => item.childAt(ix, iy)));
    }
}
