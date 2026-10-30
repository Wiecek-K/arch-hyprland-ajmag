// Look of Ajmashell's big popups (faza E ticket 13, ADR 0021; was four named looks, ADR 0006): a set of parameters,
// not a name — background (a matugen role) and its alpha 0.5–1, motion, lens flare, glass core, soft pills. Read from
// the live file ~/.local/state/ajmashell/look.json, which only Ajmashell Theme Center writes; a change applies at once.
// No file = `defaults` of look-options.json (that file holds the roles, ranges, presets and defaults: the one source,
// also for look_settings.py, which Theme Center imports); a bad field = its default, with a warning in `qs log`
// (look.mjs, the same rules as look_settings.load()).
// One background for the 7 big popups (Orbita, audio popup, calendar, media, Centrum sterowania, launcher, Keybinds):
// `background`. At alpha 1 Hyprland's blur under them is off (BlurOff.qml; was the flag `opaque`).
// IPC for tools/measure-gpu.sh: `qs -c ajmashell ipc call look set fancy` puts a preset on for the moment, without
// writing the file; a change of the file or a shell restart takes it back. No other switch in the shell (the
// Centrum sterowania's look buttons and F2 went with ticket 13).
// How to change the defaults or add a preset: ~/Projects/hyprland-lua-migration/docs/wyglady-ajmashella.md.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.singletons.theme
import "../../orbit/orbit.mjs" as Logic
import "look.mjs" as LookLogic

Singleton {
    id: root

    readonly property var options: JSON.parse(optionsFile.text())
    property var fileLook: options.defaults // the live file, read leniently
    property var override: null // IPC `look set`: a preset until the file changes
    // background, alpha, motion, flare, glass, softPills
    readonly property var current: override ?? fileLook
    // the background of every big popup
    readonly property color background: Qt.alpha(Theme.colors[current.background], current.alpha)

    // text = the file's text, null = no file
    function read(text: var): void {
        const r = LookLogic.resolve(root.options, text);
        for (const w of r.warnings)
            console.warn("Look: " + lookFile.path + ": " + w);
        root.fileLook = r.look;
        root.override = null;
    }

    // Singletons load lazily and FileView reads asynchronously: read the live file once, blocking, so the first
    // frame already has the look instead of the defaults.
    Component.onCompleted: lookFile.text()

    FileView {
        id: optionsFile
        path: Quickshell.shellPath("singletons/look/look-options.json")
        blockLoading: true
    }

    FileView {
        id: lookFile
        path: Quickshell.env("HOME") + "/.local/state/ajmashell/look.json"
        blockLoading: true
        printErrors: false // no file is the normal case: the defaults
        // Also catches Theme Center's atomic replace: FileView watches the directory (it exists: colors.json is there)
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.read(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn("Look: cannot read " + path + ", using the defaults:", FileViewError.toString(error));
            root.read(null);
        }
    }

    BlurOff {
        off: root.current.alpha >= 1
    }

    // One motion clock for the whole shell (ticket 28), Theme.orbit.fps steps a second, running only
    // while a ClockUser is active in a look with motion. Each step sets the flare's angle from the wall
    // clock — the same in every popup, and where it would be had it kept turning while all were closed
    // (user, 2026-10-07) — and emits `tick` for the Orbita's nodes and lightning, so they draw in the
    // same frame as the flare.
    property int clockUsers: 0 // orbit/ClockUser.qml
    property real flareAngle: 0 // rad, Logic.flareAngle(); OrbitBackdrop stands at 0 without motion
    readonly property real tickMs: 1000 / Theme.orbit.fps // one step of the clock
    signal tick

    Timer {
        interval: root.tickMs
        repeat: true
        running: root.clockUsers > 0 && root.current.motion
        triggeredOnStart: true // a popup opens with the flare already in place
        onTriggered: {
            root.flareAngle = Logic.flareAngle(Date.now(), Theme.orbit.flare.lap);
            root.tick();
        }
    }

    IpcHandler {
        target: "look"

        // a preset for the moment (tools/measure-gpu.sh); an unknown name changes nothing
        function set(name: string): void {
            const look = LookLogic.preset(root.options, name);
            if (look)
                root.override = look;
            else
                console.warn("Look: ipc look set: no preset " + JSON.stringify(name));
        }
    }
}
