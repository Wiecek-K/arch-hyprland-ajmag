// AudioPopup — right click on a Bar volume island (ticket 14, user 2026-10-07): choose the device and set the
// volume of the device and of each app, like pavucontrol (which it replaces on the Bar), in the Orbita's colours
// (background colour by the look, Look.qml). No lens flare in any look: the sliders and names read better on a
// plain background (user, 2026-10-07, ticket 29).
// Hangs under its island; closes on a click outside (HyprlandFocusGrab), on Esc and on a second right click.
// Own implementation; popup placement and focus grab as in orbit/Orbit.qml.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.singletons.barpopups
import qs.singletons.theme
import qs.singletons.look
import qs.prototype // PROTOTYPE C10
import qs.singletons.protogradient // PROTOTYPE C10

PopupWindow {
    id: root

    required property Item source // island the popup hangs under
    property bool microphone: false

    property real shift: 0 // px left, so the popup stays on screen (set on open)

    function toggle(): void {
        // here, not in a binding: mapToItem does not follow the island's position, which settles after start
        // (the volume islands moved to the right edge on 2026-10-07, where a stale value pushes it off screen)
        if (!visible)
            shift = Math.min(0, source.Window.width - Theme.control.margin - implicitWidth - source.mapToItem(null, 0, 0).x);
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
        windows: [root, ...BarPopups.bars]
        onCleared: root.visible = false
    }

    // ticket 27: closes on a press on the Bar outside its own islands; ticket 52: and on a change of the focused workspace
    BarElement {
        open: root.visible
        owners: [root.source]
        screenName: root.screen?.name ?? ""
        onClose: root.visible = false
    }

    visible: false
    anchor.item: source
    // under the island's left edge, moved left when it would stick out of the screen (Hyprland does not slide it)
    anchor.rect.x: shift
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
        color: ProtoGradient.on ? Theme.transparent : Look.background(Theme.control) // PROTOTYPE C10
        ProtoGradientFill { base: Look.background(Theme.control) } // PROTOTYPE C10

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
