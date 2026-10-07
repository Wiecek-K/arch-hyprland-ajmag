// AudioPopup — right click on a Bar volume island (ticket 14, user 2026-10-07): choose the device and set the
// volume of the device and of each app, like pavucontrol (which it replaces on the Bar), in the Orbita's look.
// Hangs under its island; closes on a click outside (HyprlandFocusGrab), on Esc and on a second right click.
// Own implementation; popup placement and focus grab as in orbit/Orbit.qml.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.orbit
import qs.singletons.theme
import qs.singletons.look

PopupWindow {
    id: root

    required property Item source // island the popup hangs under
    property bool microphone: false

    function toggle(): void {
        visible = !visible;
    }

    // the grab refuses a window that is not mapped yet, so arm it after the popup shows (as the Orbita)
    onVisibleChanged: Qt.callLater(() => {
        grab.active = root.visible;
        if (root.visible)
            panel.forceActiveFocus();
    })

    HyprlandFocusGrab {
        id: grab
        windows: [root]
        onCleared: root.visible = false
    }

    visible: false
    anchor.item: source
    // under the island's left edge, moved left when it would stick out of the screen (Hyprland does not slide it)
    anchor.rect.x: {
        const left = source.mapToItem(null, 0, 0).x;
        return Math.min(0, source.Window.width - Theme.control.margin - implicitWidth - left);
    }
    anchor.rect.y: 0
    anchor.rect.width: source.width
    anchor.rect.height: source.height + Theme.bar.tooltip.gap
    // qmltypes give these as Edges::Flags, which qmllint cannot resolve
    anchor.edges: Edges.Bottom | Edges.Left // qmllint disable missing-type
    anchor.gravity: Edges.Bottom | Edges.Right // qmllint disable missing-type

    implicitWidth: Theme.control.popupWidth
    implicitHeight: section.implicitHeight + 2 * Theme.control.padding
    color: Theme.transparent // only the rounded box below is drawn

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Theme.radius.lg
        color: Look.current.opaque ? Theme.control.backgroundOpaque : Theme.control.background

        focus: true
        Keys.onEscapePressed: root.visible = false

        AudioSection {
            id: section
            x: Theme.control.padding
            y: Theme.control.padding
            width: parent.width - 2 * Theme.control.padding
            microphone: root.microphone
            active: root.visible
        }
    }
}
