// Recording — whether the screen is being recorded and for how long (faza C ticket cb40), one for all screens; the
// Bar's privacy dot shows the time and a click on it stops the recording. Recording itself is
// ~/.config/hypr/scripts/screen-record.sh (SUPER+R): it writes the state file while recording and calls
// `qs -c ajmashell ipc call recording refresh` at the start and at the end (the file is also watched, and read once
// when the shell starts, so a recording started before a restart shows too). Logic: recording.mjs
// (tests tools/test-recording.mjs). wf-recorder takes the picture without PipeWire and its sound stream captures a
// sink, so Privacy (privacy.mjs) does not see it.
// Own implementation.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.singletons.apps
import "recording.mjs" as Logic

Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/screen-record.sh"
    property var state: null // { pid, startedAt, path } while recording (recording.mjs parseState)
    readonly property bool active: state !== null
    property real now: Date.now() / 1000 // s; moves only while recording
    readonly property string elapsedText: active ? Logic.elapsedText(now - state.startedAt) : ""

    // the text whose width a label takes, so it does not change every second (recording.mjs widthTemplate)
    function widthTemplate(text: string): string {
        return Logic.widthTemplate(text);
    }

    // through Hyprland, like the shortcut (Apps.run): the script waits for no one, the recording's own run sends
    // the notification
    function stop(): void {
        Apps.run([script, "stop"], "");
    }

    FileView {
        id: stateFile
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ajmashell/screen-record"
        printErrors: false // no file = not recording, the normal case
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.state = Logic.parseState(text())
        onLoadFailed: root.state = null
    }

    // screen-record.sh: the state file was written or removed
    IpcHandler {
        target: "recording"

        function refresh(): void {
            stateFile.reload();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.now = Date.now() / 1000
    }
}
