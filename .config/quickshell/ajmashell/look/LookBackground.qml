// Background of the 7 big popups (faza E ticket 14, ADR 0021): the one place that draws it, under the popup's
// content. The look's background (Look.background), or the look's gradient over it (GradientFill.qml) when its style
// is not "off". The popup's own box stays transparent: `color: Theme.transparent` + `LookBackground {}`.
// A future shadow under the popups (ticket C13) belongs here too.
// SPDX-License-Identifier: AGPL-3.0-or-later

import QtQuick
import qs.singletons.look
import qs.singletons.theme

Rectangle {
    id: bg

    readonly property var settings: Look.current.gradient
    readonly property bool gradientOn: settings.style !== "off"

    anchors.fill: parent
    z: -1
    radius: (parent as Rectangle)?.radius ?? 0 // inside a ClippingRectangle (launcher, Keybinds) the box clips the corners
    color: gradientOn ? Theme.transparent : Look.background

    GradientFill {
        anchors.fill: parent
        visible: bg.gradientOn
        settings: bg.gradientOn ? bg.settings : null
        colorA: Theme.colors[bg.settings.a]
        colorB: Theme.colors[bg.settings.b]
        base: Look.background
        radius: bg.radius
    }
}
