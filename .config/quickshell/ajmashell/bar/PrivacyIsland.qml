// PrivacyIsland — a red dot in a round island while an app uses the microphone, the camera or shares the screen,
// like a phone's recording dot (faza C ticket 05; user, 2026-11-10: one dot, no separate icons). Hidden otherwise.
// Sits right of the workspaces (Bar.qml); nothing hangs off it, so showing it never moves another island.
// Fades in and out in Theme.motion.fast. A click opens the list of apps (PrivacyPopup.qml).
// Own implementation; idea after DankMaterialShell quickshell/Modules/DBar/Widgets/PrivacyIndicator.qml (MIT):
// https://github.com/AvengeMedia/DankMaterialShell/blob/4a51cd642ca08facf4c78940ef393fc1e880bcd1/quickshell/Modules/DBar/Widgets/PrivacyIndicator.qml

import QtQuick
import qs.singletons.privacy
import qs.singletons.theme

Island {
    id: root

    circle: true
    opacity: Privacy.active ? 1 : 0
    visible: opacity > 0 // no clicks on a hidden dot

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.motion.fast
        }
    }

    onClicked: popup.toggle()

    Rectangle {
        width: Theme.privacy.dotSize
        height: Theme.privacy.dotSize
        radius: width / 2
        color: Theme.privacy.dot
    }

    PrivacyPopup {
        id: popup
        source: root
    }
}
