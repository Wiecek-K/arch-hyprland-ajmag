// PrivacyIsland — a red dot and "Rec" in an island while an app uses the microphone, the camera or shares the
// screen, like a camera's recording mark (faza C ticket 05; user, 2026-11-10: one dot, no separate icons; then
// "Rec" next to it, small and heavy). Hidden otherwise.
// Screen recording (faza C ticket cb40, SUPER+R, singletons/recording): while it runs the dot shows, with the
// recording's time instead of "Rec", and a left click stops it (no list of apps then; user, 2026-11-10).
// Sits right of the workspaces (Bar.qml); nothing hangs off it, so showing it never moves another island.
// Fades in and out in Theme.motion.fast. A click opens the list of apps (PrivacyPopup.qml).
// Own implementation; idea after DankMaterialShell quickshell/Modules/DBar/Widgets/PrivacyIndicator.qml (MIT):
// https://github.com/AvengeMedia/DankMaterialShell/blob/4a51cd642ca08facf4c78940ef393fc1e880bcd1/quickshell/Modules/DBar/Widgets/PrivacyIndicator.qml

import QtQuick
import qs.singletons.privacy
import qs.singletons.recording
import qs.singletons.theme

Island {
    id: root

    spacing: Theme.privacy.labelGap
    opacity: Privacy.active || Recording.active ? 1 : 0
    visible: opacity > 0 // no clicks on a hidden dot

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.motion.fast
        }
    }

    onClicked: Recording.active ? Recording.stop() : popup.toggle()

    Rectangle {
        id: dot
        width: Theme.privacy.dotSize
        height: Theme.privacy.dotSize
        radius: width / 2
        color: Theme.privacy.dot
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: Recording.active ? Recording.elapsedText : Theme.privacy.labelText
        font: metrics.font
        color: Theme.privacy.label
        // the middle of the capitals (baseline to the top of "R") on the dot's middle, not the middle of the line
        // box with its descent (user, 2026-11-10: centre it vertically): the baseline half the drawn "R" below the
        // dot's centre, in whole pixels (Qt 6 FontMetrics has no capHeight; the drawn "R" is 8 px at 11 px)
        anchors.baseline: dot.verticalCenter
        anchors.baselineOffset: Math.round(metrics.tightBoundingRect("R").height / 2)
        // "Rec": as wide as the drawn letters: a monospace cell is wider than "c", and its empty end made the right
        // padding 4 px bigger than the left one (user, 2026-11-10; measured 15 vs 19 px).
        // The time (ticket cb40): bigger (Theme.privacy.timeSize), as wide as "00:00" and right-aligned, so there is
        // room left of it for the tens of minutes (user, 2026-11-10) and the island keeps its width from 0:00 to
        // 59:59 (recording.mjs widthTemplate); the width changes only from "Rec" to the time and at one hour — then
        // smoothly, in Theme.motion.fast. Cells, not drawn digits: right-aligned text ends at its last cell.
        width: Recording.active ? Math.ceil(metrics.advanceWidth(Recording.widthTemplate(text)))
            : Math.ceil(metrics.tightBoundingRect(text).right)
        // only the time: "Rec" is as wide as its drawn letters, right-aligned its empty last cell would push it left
        horizontalAlignment: Recording.active ? Text.AlignRight : Text.AlignLeft

        Behavior on width {
            NumberAnimation {
                duration: Theme.motion.fast
            }
        }
    }

    FontMetrics {
        id: metrics
        font.family: Theme.font.family
        font.pixelSize: Recording.active ? Theme.privacy.timeSize : Theme.privacy.labelSize
        font.weight: Theme.privacy.labelWeight
    }

    PrivacyPopup {
        id: popup
        source: root
    }

    // no list while recording (user, 2026-11-10): one open when the recording starts closes, since a click on the dot
    // now stops the recording and could not close it
    Connections {
        target: Recording

        function onActiveChanged(): void {
            if (Recording.active)
                popup.visible = false;
        }
    }
}
