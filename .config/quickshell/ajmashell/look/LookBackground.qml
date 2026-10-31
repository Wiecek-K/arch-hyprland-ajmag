// Background of the 7 big popups (faza E ticket 14, ADR 0021): the one place that draws it, under the popup's
// content. The look's background (Look.background), or the look's gradient over it (GradientFill.qml) when its style
// is not "off". The popup's own box stays transparent: `color: Theme.transparent` + `LookBackground {}`.
// The aurora (ticket E16) drifts with Look's motion clock while its popup is shown in a look with motion.
// A future shadow under the popups (ticket C13) belongs here too.
// SPDX-License-Identifier: AGPL-3.0-or-later

import QtQuick
import Quickshell
import qs.orbit
import qs.singletons.look
import qs.singletons.theme

Rectangle {
    id: bg

    readonly property var settings: Look.current.gradient
    readonly property bool gradientOn: settings.style !== "off"
    // the popup's window is shown (the item itself stays visible in a hidden window)
    readonly property bool shown: (bg.QsWindow.window as QsWindow)?.visible ?? false
    readonly property bool drifts: settings.style === "aurora" && Look.current.motion && shown
    // wall clock in seconds while it drifts: the same in every popup, and where it would be had it kept moving
    property real time: 0

    anchors.fill: parent
    z: -1
    radius: (parent as Rectangle)?.radius ?? 0 // inside a ClippingRectangle (launcher, Keybinds) the box clips the corners
    color: gradientOn ? Theme.transparent : Look.background

    // set before the first frame of an opened popup, so the blobs do not jump from where they stood when it closed
    onDriftsChanged: if (drifts) time = Date.now() / 1000

    ClockUser {
        active: bg.drifts
    }

    Connections {
        target: Look
        enabled: bg.drifts
        function onTick(): void {
            bg.time = Date.now() / 1000;
        }
    }

    GradientFill {
        anchors.fill: parent
        visible: bg.gradientOn
        settings: bg.gradientOn ? bg.settings : null
        colorA: Theme.colors[bg.settings.a]
        colorB: Theme.colors[bg.settings.b]
        base: Look.background
        radius: bg.radius
        time: bg.drifts ? bg.time : 0
    }
}
