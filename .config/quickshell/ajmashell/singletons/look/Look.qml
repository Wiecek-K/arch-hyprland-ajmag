// Look of the Orbita and the launcher (ticket 13, user 2026-10-06): two set looks, "basic" and
// "fancy" (their picks in Theme.orbit.looks), plus "prototype", the developer's look whose picks
// change with the keys B, C, P and S in the Orbita (TEMPORARY, removed with the variants).
// F2 in the Orbita or the launcher cycles basic → fancy → prototype, or
// `qs -c ajmashell ipc call look cycle` / `qs -c ajmashell ipc call look set fancy`.
// Note: ~/Projects/hyprland-lua-migration/.scratch/faza-b/prototyp-wygladu.md.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var modes: ["basic", "fancy", "prototype"]
    property string mode: "prototype" // the user is still judging the variants; a reload starts here

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
