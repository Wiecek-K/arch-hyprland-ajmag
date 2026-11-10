// PrivacyPopup — a click on the Bar's privacy dot (faza C ticket 05): one row per app using the microphone, the
// camera or the screen, "Firefox — mikrofon, kamera" (user, 2026-11-10: a small list under the dot, no buttons).
// Dressed and placed like the tray menu (bar/TrayMenu.qml, Theme.bar.menu). Closes on a click outside
// (HyprlandFocusGrab), on Esc (BarPopups), on a second click on the dot and when nothing records any more.
// Own implementation.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.singletons.barpopups
import qs.singletons.privacy
import qs.singletons.theme

PopupWindow {
    id: root

    required property Item source // the privacy island

    function toggle(): void {
        visible = !visible;
    }

    visible: false
    anchor.item: source
    anchor.rect.x: 0
    anchor.rect.y: 0
    anchor.rect.width: source.width
    anchor.rect.height: source.height + Theme.bar.tooltip.gap
    // qmltypes give these as Edges::Flags, which qmllint cannot resolve
    anchor.edges: Edges.Bottom // qmllint disable missing-type
    anchor.gravity: Edges.Bottom // qmllint disable missing-type

    implicitWidth: Math.ceil(list.implicitWidth) + 2 * Theme.bar.menu.padding
    implicitHeight: Math.ceil(list.implicitHeight) + 2 * Theme.bar.menu.padding
    color: Theme.transparent // only the rounded box below is drawn

    Connections {
        target: Privacy

        function onActiveChanged(): void {
            if (!Privacy.active)
                root.visible = false;
        }
    }

    // The grab refuses a window that is not mapped yet, so arm it after the popup shows.
    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => grab.active = visible);
        else
            grab.active = false;
    }

    HyprlandFocusGrab {
        id: grab
        windows: [root, ...BarPopups.bars]
        onCleared: root.visible = false
    }

    // closes on a press on the Bar outside the dot and on a change of the focused workspace (tickets 27, 52)
    BarElement {
        open: root.visible
        owners: [root.source]
        screenName: root.screen?.name ?? ""
        onClose: root.visible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.lg
        color: Theme.bar.menu.background

        Column {
            id: list
            anchors.centerIn: parent

            Repeater {
                model: Privacy.rows

                Text {
                    required property var modelData

                    // a row of the tray menu's height, text with its padding
                    height: Theme.bar.menu.rowHeight
                    leftPadding: Theme.bar.menu.rowPadding
                    rightPadding: Theme.bar.menu.rowPadding
                    verticalAlignment: Text.AlignVCenter
                    text: Privacy.rowText(modelData)
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.sizeSmall
                    font.weight: Theme.font.weight
                    color: Theme.bar.menu.text
                }
            }
        }
    }
}
