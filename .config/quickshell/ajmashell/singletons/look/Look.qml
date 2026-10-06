// Look of the Orbita and the launcher (ticket 13, user 2026-10-06): set looks "basic", "fancy" and
// "still" (fancy without motion, user 2026-10-06), their picks in Theme.orbit.looks. The developer's
// "prototype" look with the keys B, C, P and S was removed after code review 2 (user, 2026-10-06: "for now").
// F2 in the Orbita or the launcher switches to the next look, or
// `qs -c ajmashell ipc call look cycle` / `qs -c ajmashell ipc call look set fancy`.
// Note: ~/Projects/hyprland-lua-migration/.scratch/faza-b/prototyp-wygladu.md.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var modes: ["basic", "fancy", "still"]
    property string mode: "fancy" // a reload starts here

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
