// Hyprland's blur under the big popups, off for a look with alpha 1 (ticket 13; faza E ticket 13: the alpha of the
// live look file, was the flag `opaque` of fancy2): ajmashellBlurOff in ~/.config/hypr/configs/functions.lua switches
// the rules from rules.lua. Applied on a change, at start (a shell reload while Hyprland still has the rules on) and
// after a config reload, which brings the rules back disabled. A change while hyprctl still runs is applied when it
// ends (two quick saves of the look).

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    required property bool off
    property bool stale: false // `off` changed while hyprctl ran

    function apply(): void {
        if (proc.running) {
            stale = true;
            return;
        }
        proc.command = ["hyprctl", "eval", `require("configs.functions").ajmashellBlurOff(${off})`];
        proc.running = true;
    }

    onOffChanged: apply()
    Component.onCompleted: apply()

    Process {
        id: proc

        onRunningChanged: {
            if (!running && root.stale) {
                root.stale = false;
                root.apply();
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "configreloaded")
                root.apply();
        }
    }
}
