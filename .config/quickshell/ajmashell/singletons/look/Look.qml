// Look of the Orbita and the launcher (ticket 13, user 2026-10-06): set looks "basic", "fancy", "fancy2"
// (fancy on an opaque background, user 2026-10-07) and "still" (fancy without motion, user 2026-10-06),
// their picks in Theme.orbit.looks (`current`). A look with `opaque` also turns off Hyprland's blur under
// the Orbita and the launcher (BlurOff.qml); `tinted` (still) keeps the blur under fancy2's colour. The developer's
// "prototype" look with the keys B, C, P and S was removed after code review 2 (user, 2026-10-06: "for now").
// Switched only in the Centrum sterowania (ticket 14, user 2026-10-07: one place, easier to keep): its look
// buttons, F2 there for the next look, or
// `qs -c ajmashell ipc call look cycle` / `qs -c ajmashell ipc call look set fancy`.
// Decisions: ADR 0006 in ~/Projects/hyprland-lua-migration/docs/adr. How to change the default look or a
// look's picks: ~/Projects/hyprland-lua-migration/docs/wyglady-ajmashella.md.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.singletons.theme
import "../../orbit/orbit.mjs" as Logic

Singleton {
    id: root

    readonly property var modes: ["basic", "fancy", "fancy2", "still"]
    property string mode: "fancy2" // a reload starts here (user, 2026-10-07; was "still")
    readonly property var current: Theme.orbit.looks[mode] // flags: flare, glass, softPills, motion, opaque, tinted

    // Background of a big popup in the current look; style: a Theme style with background,
    // backgroundOpaque and backgroundTinted (Theme.orbit, Theme.control, Theme.launcher).
    function background(style: var): color {
        return current.opaque ? style.backgroundOpaque : current.tinted ? style.backgroundTinted : style.background;
    }

    BlurOff {
        off: root.current.opaque
    }

    // One motion clock for the whole shell (ticket 28), Theme.orbit.fps steps a second, running only
    // while a ClockUser is active in a look with motion. Each step sets the flare's angle from the wall
    // clock — the same in every popup, and where it would be had it kept turning while all were closed
    // (user, 2026-10-07) — and emits `tick` for the Orbita's nodes and lightning, so they draw in the
    // same frame as the flare.
    property int clockUsers: 0 // orbit/ClockUser.qml
    property real flareAngle: 0 // rad, Logic.flareAngle(); OrbitBackdrop stands at 0 without motion
    signal tick

    Timer {
        interval: 1000 / Theme.orbit.fps
        repeat: true
        running: root.clockUsers > 0 && root.current.motion
        triggeredOnStart: true // a popup opens with the flare already in place
        onTriggered: {
            root.flareAngle = Logic.flareAngle(Date.now(), Theme.orbit.flare.lap);
            root.tick();
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
