// Switching between the elements the Bar opens (ticket 27, user 2026-10-09): Orbita, audio popup, tray menu,
// media popup, Centrum sterowania. One click on another island closes the open element and opens the next one.
// How: each element's HyprlandFocusGrab has the Bar windows (`bars`) in `windows`, so a click on the Bar is no
// longer eaten by clearing the grab; the Bar reports every press (`press`) and each open element closes itself
// through its BarElement unless the press is on one of its own islands — that island's toggle still closes
// it on a second click. A click beside the Bar and the element still clears the grab and only closes.
// A change of the focused workspace closes an open element (ticket 52, user 2026-10-16: following the focused
// monitor, ticket 27, was irritating): `focusSettled` once Hyprland's burst of events ends, BarElement decides.
// Pure logic: popups.mjs (tests tools/test-bar-popups.mjs). Own implementation.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.singletons.theme
import "popups.mjs" as Logic

Singleton {
    id: root

    property list<QtObject> bars: [] // the Bar's PanelWindows on all screens (Bar.qml)

    // open elements (BarElement counts itself). While > 0 the Bar windows take the keyboard on demand: with the
    // pointer over a Bar popup Hyprland gives the keyboard to the popup's parent, the Bar's layer, and with
    // keyboardFocus None there Esc was lost (ticket 42, user 2026-10-16)
    property int openCount: 0

    signal escaped // Esc on a Bar window (it has the keyboard while an element is open): open elements close
    signal pressed(var hit) // a press on a Bar; hit = the deepest item under the pointer, null = none
    signal focusSettled(int workspace) // the focused workspace changed (id), read after Hyprland's events settle

    // Read once the burst ends, as bar/Workspaces.qml: moving to the other monitor, Hyprland first reports that
    // monitor's old workspace (focusedmon), a few ms later the new one (workspace)
    // set by the timer, not bound: a binding would already hold the new id when the timer compares
    property int settledWorkspace: 0

    Component.onCompleted: settledWorkspace = Hyprland.focusedWorkspace?.id ?? 0

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged(): void {
            settleTimer.restart();
        }
        function onFocusedMonitorChanged(): void {
            settleTimer.restart();
        }
    }

    Timer {
        id: settleTimer
        interval: Theme.motion.settle
        onTriggered: {
            const id = Hyprland.focusedWorkspace?.id ?? 0;
            if (id === root.settledWorkspace)
                return;
            root.settledWorkspace = id;
            root.focusSettled(id);
        }
    }

    // the active workspace of monitor `name` (0 = unknown): an element's home when it opens
    function activeWorkspace(name: string): int {
        return Hyprland.monitors.values.find(m => m.name === name)?.activeWorkspace?.id ?? 0;
    }

    // a press at (x, y) in `content`, the Bar's item holding every island
    function press(content: Item, x: real, y: real): void {
        pressed(Logic.deepestAt(content, x, y, (item, ix, iy) => item.childAt(ix, iy)));
    }
}
