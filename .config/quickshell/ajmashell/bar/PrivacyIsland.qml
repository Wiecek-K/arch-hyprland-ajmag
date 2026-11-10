// PrivacyIsland — a red dot and "Rec" in an island while an app uses the microphone, the camera or shares the
// screen, like a camera's recording mark (faza C ticket 05; user, 2026-11-10: one dot, no separate icons; then
// "Rec" next to it, small and heavy). Hidden otherwise.
// Sits right of the workspaces (Bar.qml); nothing hangs off it, so showing it never moves another island.
// Fades in and out in Theme.motion.fast. A click opens the list of apps (PrivacyPopup.qml).
// Own implementation; idea after DankMaterialShell quickshell/Modules/DBar/Widgets/PrivacyIndicator.qml (MIT):
// https://github.com/AvengeMedia/DankMaterialShell/blob/4a51cd642ca08facf4c78940ef393fc1e880bcd1/quickshell/Modules/DBar/Widgets/PrivacyIndicator.qml

import QtQuick
import qs.singletons.privacy
import qs.singletons.theme

Island {
    id: root

    spacing: Theme.privacy.labelGap
    opacity: Privacy.active ? 1 : 0
    visible: opacity > 0 // no clicks on a hidden dot

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.motion.fast
        }
    }

    onClicked: popup.toggle()

    Rectangle {
        id: dot
        width: Theme.privacy.dotSize
        height: Theme.privacy.dotSize
        radius: width / 2
        color: Theme.privacy.dot
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: Theme.privacy.labelText
        font: metrics.font
        color: Theme.privacy.label
        // the middle of the capitals (baseline to the top of "R") on the dot's middle, not the middle of the line
        // box with its descent (user, 2026-11-10: centre it vertically): the baseline half the drawn "R" below the
        // dot's centre, in whole pixels (Qt 6 FontMetrics has no capHeight; the drawn "R" is 8 px at 11 px)
        anchors.baseline: dot.verticalCenter
        anchors.baselineOffset: Math.round(metrics.tightBoundingRect("R").height / 2)
        // as wide as the drawn letters: a monospace cell is wider than "c", and its empty end made the right padding
        // 4 px bigger than the left one (user, 2026-11-10; measured 15 vs 19 px)
        width: Math.ceil(metrics.tightBoundingRect(text).right)
    }

    FontMetrics {
        id: metrics
        font.family: Theme.font.family
        font.pixelSize: Theme.privacy.labelSize
        font.weight: Theme.privacy.labelWeight
    }

    PrivacyPopup {
        id: popup
        source: root
    }
}
