// "Activate Linux" (Theme Center 1.0.next ticket tc05): a parody of Windows' "Activate Windows" watermark, two lines
// in the bottom right corner of every monitor. Switched on in Theme Center's Fun tab (Extras.current.activateLinux),
// off by default; off = no window at all. The user's wish (2026-11-12): a fixed place, cannot be moved, always on top.
// So a layer, not a window: anchored to the corner (Hyprland neither tiles nor moves layers), on the Overlay layer
// (above every window, a fullscreen one included), an empty input mask (clicks go through, nothing to grab or close)
// and no exclusive zone (windows do not make room for it). Not shown on the lock screen.
// Own implementation. Idea: the DMS plugin activateLinux (https://github.com/hthienloc/dms-plugins@0a2976d,
// activateLinux/ActivateLinuxWidget.qml, MIT) and the activate_linux example of Quickshell
// (https://git.outfoxxed.me/quickshell/quickshell-examples, research B04 §1.5); no code copied.
// Look: Theme.activateLinux.
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.singletons.extras
import qs.singletons.theme

Scope {
    Variants {
        // every monitor while the extra is on; an empty list = no window, nothing drawn
        model: Extras.current.activateLinux ? Quickshell.screens : []

        // qmltypes mark PanelWindow uncreatable; Quickshell substitutes the Wayland implementation at runtime
        PanelWindow { // qmllint disable uncreatable-type
            id: win

            required property var modelData

            screen: win.modelData
            anchors {
                bottom: true
                right: true
            }
            // qmltypes do not resolve PanelWindow.margins (see the uncreatable-type note above); works at runtime
            margins.bottom: Theme.activateLinux.marginBottom // qmllint disable unqualified unresolved-type missing-property
            margins.right: Theme.activateLinux.marginRight // qmllint disable unqualified unresolved-type missing-property
            implicitWidth: lines.implicitWidth
            implicitHeight: lines.implicitHeight
            color: Theme.transparent
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "ajmashell-activate-linux"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            Column {
                id: lines

                spacing: Theme.activateLinux.lineGap

                Text {
                    text: "Activate Linux"
                    color: Theme.activateLinux.text
                    font.family: Theme.font.family
                    font.pixelSize: Theme.activateLinux.titleSize
                    font.weight: Theme.activateLinux.weight
                }

                Text {
                    text: "Go to Settings to activate Linux."
                    color: Theme.activateLinux.text
                    font.family: Theme.font.family
                    font.pixelSize: Theme.activateLinux.bodySize
                    font.weight: Theme.activateLinux.weight
                }
            }
        }
    }
}
