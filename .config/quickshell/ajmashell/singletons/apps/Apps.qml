// Starts programs for the shell through Hyprland (apps.mjs execRequest): the launcher, the Panel zasilania,
// the Wi-Fi island's right click and the Orbita's "program" button. One place instead of a
// Hyprland.dispatch(…) copy in each component (ticket 23).

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "apps.mjs" as Logic

Singleton {
    // command: argv list; workingDirectory: "" = Hyprland's
    function run(command: list<string>, workingDirectory: string): void {
        Hyprland.dispatch(Logic.execRequest(command, workingDirectory));
    }

    // the emergency Wi-Fi program (D2): enterprise / WEP networks the Orbita leaves to it
    function networkEditor(): void {
        run(["nm-connection-editor"], "");
    }
}
