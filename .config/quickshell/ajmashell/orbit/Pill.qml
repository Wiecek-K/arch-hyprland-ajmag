// Pill — rounded button of the Orbita (tabs, the module switch, the core's actions); the audio popup and the
// Centrum sterowania use it too, so all three look alike (user, 2026-10-07).
// The look's `softPills` flag (Look.qml): faint fill with coloured text instead of a filled button.
// Own implementation (was an inline component of Orbit.qml until ticket 14).

import QtQuick
import qs.singletons.theme
import qs.singletons.look

Rectangle {
    id: pill

    property string text
    property bool active: false
    property int fontSize: Theme.font.sizeSmall
    signal clicked

    implicitWidth: Math.ceil(label.implicitWidth) + 2 * Theme.spacing.lg
    height: Theme.orbit.tabHeight
    radius: height / 2
    readonly property bool soft: Look.current.softPills // faint fill, coloured text (fancy look)
    readonly property bool hot: pillHover.hovered && enabled
    color: soft ? (active ? Qt.alpha(Theme.orbit.tab, Theme.orbit.softPill.active) : Qt.alpha(Theme.orbit.text, hot ? Theme.orbit.softPill.hover : Theme.orbit.softPill.idle))
                : active ? Theme.orbit.tab : hot ? Theme.orbit.hover : Theme.orbit.button
    opacity: enabled ? 1 : Theme.orbit.dimmed

    OrbitText {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, pill.width - 2 * Theme.spacing.sm)
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: pill.fontSize
        color: pill.soft ? (pill.active ? Theme.orbit.selected : Theme.orbit.text) : pill.active ? Theme.orbit.tabText : Theme.orbit.buttonText
        text: pill.text
    }

    HoverHandler {
        id: pillHover
    }

    TapHandler {
        enabled: pill.enabled
        onTapped: pill.clicked()
    }
}
