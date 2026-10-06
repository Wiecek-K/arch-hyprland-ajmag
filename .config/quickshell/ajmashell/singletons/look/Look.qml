// Look of the Orbita and the launcher (ticket 13, user 2026-10-06): set looks "basic", "fancy", "fancy2"
// (fancy on an opaque background, user 2026-10-07) and "still" (fancy without motion, user 2026-10-06),
// their picks in Theme.orbit.looks. A look with `opaque` also turns off Hyprland's blur under the Orbita
// and the launcher (~/.config/hypr/configs/rules.lua, ajmashellOpaque in functions.lua), again after a
// config reload, which brings the rules back disabled. The developer's
// "prototype" look with the keys B, C, P and S was removed after code review 2 (user, 2026-10-06: "for now").
// F2 in the Orbita or the launcher switches to the next look, or
// `qs -c ajmashell ipc call look cycle` / `qs -c ajmashell ipc call look set fancy`.
// Note: ~/Projects/hyprland-lua-migration/.scratch/faza-b/prototyp-wygladu.md. How to change the default
// look or a look's picks: ~/Projects/hyprland-lua-migration/docs/wyglady-ajmashella.md.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.singletons.theme

Singleton {
    id: root

    readonly property var modes: ["basic", "fancy", "fancy2", "still"]
    property string mode: "fancy2" // a reload starts here (user, 2026-10-07; was "still")
    readonly property bool opaque: Theme.orbit.looks[mode].opaque

    function applyBlur(): void {
        blurProc.command = ["hyprctl", "eval", `require("configs.functions").ajmashellOpaque(${opaque})`];
        blurProc.running = true;
    }

    onOpaqueChanged: applyBlur()
    Component.onCompleted: applyBlur() // a shell reload while Hyprland still has the rules on

    Process {
        id: blurProc
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "configreloaded")
                root.applyBlur();
        }
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
