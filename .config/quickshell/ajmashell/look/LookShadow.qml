// Shadow under a big popup (faza C ticket 13): a soft shadow around `target` (the popup's rounded box), drawn into
// the transparent band of Theme.shadow.margin that the popup window keeps around the box. Only outside the box (the
// inside is masked out), like Hyprland's window shadow: a translucent look keeps its own background colour.
// A sibling placed before the box, not inside LookBackground: in the launcher and Keybinds the background sits in a
// ClippingRectangle, which would cut the shadow off.
// QtQuick.Effects RectangularShadow after end-4/dots-hyprland StyledRectangularShadow.qml (GPL-3.0), idea only:
// https://github.com/end-4/dots-hyprland/blob/2f0c8bf/dots/.config/quickshell/ii/modules/common/widgets/StyledRectangularShadow.qml
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.singletons.theme

Item {
    id: root

    required property Item target // the popup's rounded box
    readonly property real radius: (target as Rectangle)?.radius ?? 0
    readonly property int margin: Theme.shadow.margin

    x: target.x - margin
    y: target.y - margin
    width: target.width + 2 * margin
    height: target.height + 2 * margin

    layer.enabled: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskInverted: true // keep the shadow where the box is not
        maskSource: hole
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0 // soft, antialiased rounded edge
    }

    RectangularShadow {
        x: root.margin
        y: root.margin
        width: root.target.width
        height: root.target.height
        radius: root.radius
        blur: Theme.shadow.blur
        offset: Qt.vector2d(Theme.shadow.offsetX, Theme.shadow.offsetY)
        color: Theme.shadow.color
        cached: true
    }

    // the box's shape, only as the mask
    Item {
        id: hole
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            x: root.margin
            y: root.margin
            width: root.target.width
            height: root.target.height
            radius: root.radius
            color: Theme.colors.shadow // opaque: only its alpha matters
        }
    }
}
