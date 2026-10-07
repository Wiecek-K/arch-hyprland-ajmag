// Look of the Orbita and the launcher (ticket 13, user 2026-10-06): set looks "basic", "fancy", "fancy2"
// (fancy on an opaque background, user 2026-10-07) and "still" (fancy without motion, user 2026-10-06),
// their picks in Theme.orbit.looks (`current`). A look with `opaque` also turns off Hyprland's blur under
// the Orbita and the launcher (BlurOff.qml). The developer's
// "prototype" look with the keys B, C, P and S was removed after code review 2 (user, 2026-10-06: "for now").
// F2 in the Orbita or the launcher switches to the next look, or
// `qs -c ajmashell ipc call look cycle` / `qs -c ajmashell ipc call look set fancy`.
// Decisions: ADR 0006 in ~/Projects/hyprland-lua-migration/docs/adr. How to change the default look or a
// look's picks: ~/Projects/hyprland-lua-migration/docs/wyglady-ajmashella.md.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.singletons.theme

Singleton {
    id: root

    readonly property var modes: ["basic", "fancy", "fancy2", "still"]
    property string mode: "fancy2" // a reload starts here (user, 2026-10-07; was "still")
    readonly property var current: Theme.orbit.looks[mode] // flags: flare, glass, softPills, motion, opaque

    BlurOff {
        off: root.current.opaque
    }

    function cycle(): void {
        mode = modes[(modes.indexOf(mode) + 1) % modes.length];
    }

    IpcHandler {
        target: "look"

        function cycle(): void {
            root.cycle();
        }

        function set(mode: string): void {
            if (root.modes.includes(mode))
                root.mode = mode;
        }
    }
}
