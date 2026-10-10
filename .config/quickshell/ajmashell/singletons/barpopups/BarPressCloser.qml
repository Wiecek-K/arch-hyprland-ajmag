// BarPressCloser — closes an element the Bar opens when a press on the Bar lands outside its own islands
// (ticket 27, see BarPopups.qml). The element's grab lets Bar clicks through, so the island under the press opens
// its own element in the same click.
// Own implementation.

import QtQuick
import qs.singletons.barpopups
import "popups.mjs" as Logic

Connections {
    id: root

    required property bool open // the element is shown
    required property var owners // its own islands (list of Items), or a test on the hit item (Logic.onBell)

    signal close

    target: BarPopups

    function onPressed(hit: var): void {
        if (root.open && Logic.closesOn(hit, root.owners))
            root.close();
    }
}
