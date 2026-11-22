// Extras of Ajmashell (Theme Center 1.0.next ticket tc05): jokes and small add-ons, each switched on in Theme Center's
// Fun tab, all off by default. Read from the live file ~/.local/state/ajmashell/extras.json, which only Theme Center
// writes; a change applies at once. No file = every extra off; a bad field = that extra off, with a warning in `qs log`
// (extras.mjs, the same rules as extras_settings.py, which Theme Center imports). The list of extras:
// extras-options.json. Own implementation, same pattern as singletons/look/Look.qml.
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "extras.mjs" as Logic

Singleton {
    id: root

    readonly property var options: JSON.parse(optionsFile.text())
    // {name: bool} of every extra in extras-options.json
    property var current: Logic.resolve(options, null).extras

    // text = the file's text, null = no file
    function read(text: var): void {
        const r = Logic.resolve(root.options, text);
        for (const w of r.warnings)
            console.warn("Extras: " + extrasFile.path + ": " + w);
        root.current = r.extras;
    }

    // read the live file once, blocking: an extra switched on is there from the first frame
    Component.onCompleted: extrasFile.text()

    FileView {
        id: optionsFile
        path: Quickshell.shellPath("singletons/extras/extras-options.json")
        blockLoading: true
    }

    FileView {
        id: extrasFile
        path: Quickshell.env("HOME") + "/.local/state/ajmashell/extras.json"
        blockLoading: true
        printErrors: false // no file is the normal case: every extra off
        // also catches Theme Center's atomic replace: FileView watches the directory
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.read(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn("Extras: cannot read " + path + ", every extra off:", FileViewError.toString(error));
            root.read(null);
        }
    }
}
