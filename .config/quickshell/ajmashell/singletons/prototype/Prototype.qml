// TEMPORARY (ticket 13, user 2026-10-06): switch between the basic look of the Orbita and the launcher
// and the prototype look being tried out (Orbita background / core / buttons / node shapes, flare behind
// the launcher list). F2 in the Orbita or the launcher, or `qs -c ajmashell ipc call prototype toggle`.
// Note: ~/Projects/hyprland-lua-migration/.scratch/faza-b/prototyp-wygladu.md. Remove with the variants.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: true // the prototype is what the user is judging; a reload starts with it

    function toggle(): void {
        active = !active;
    }

    IpcHandler {
        target: "prototype"

        function toggle(): void {
            root.toggle();
        }

        function set(on: bool): void {
            root.active = on;
        }
    }
}
