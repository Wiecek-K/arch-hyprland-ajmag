// Lens flare behind the Orbita and the launcher's list in the fancy look (ticket 13, user 2026-10-06:
// "the background is boring"; picked from 15 variants: "flare, no streak"). A bright source drifts
// round the edge with a row of ghosts on the far side of the centre, like a camera lens looking at a
// light. Drawn over the flat background, under the content. Values in Theme.orbit (flare…).
// Ticket 28: one angle for every flare in the shell (Look.flareAngle, from the wall clock), so the
// Orbita, the launcher, the Centrum sterowania, the shortcuts, the player and the power panel all show
// it in the same place (user, 2026-10-07: "gives an impression of carelessness"). A popup sets `open`;
// the flare then holds Look's clock running in a look with motion. Without motion it stands at `phase`.
// Own code, no donor.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.singletons.look
import qs.singletons.theme

Item {
    id: backdrop

    property bool open: false // its popup is shown
    property real radius: Theme.radius.lg // corners of the panel it fills
    // the orbit's centre: the field above the tab row
    readonly property real cx: width / 2
    readonly property real cy: height / 2 - Theme.orbit.tabHeight / 2
    // the source, one lap per Theme.orbit.flare.lap
    readonly property real theta: (Look.current.motion ? Look.flareAngle : 0) + Theme.orbit.flare.phase
    readonly property real sx: cx + Math.cos(theta) * width * Theme.orbit.flare.orbit
    readonly property real sy: cy + Math.sin(theta) * height * Theme.orbit.flare.orbit

    clip: true

    ClockUser {
        active: backdrop.open && backdrop.visible
    }

    // glow of the source
    Wash {
        centerX: backdrop.sx
        centerY: backdrop.sy
        reach: Theme.orbit.flare.reach
        stops: Theme.orbit.flareGlowStops
    }

    // ghosts on the axis from the source through the centre
    Repeater {
        model: Theme.orbit.flareGhosts

        Wash {
            required property var modelData
            centerX: backdrop.sx + (backdrop.cx - backdrop.sx) * modelData.t
            centerY: backdrop.sy + (backdrop.cy - backdrop.sy) * modelData.t
            reach: modelData.size
            // a ghost has a brighter rim, like an aperture reflection
            stops: [[0, modelData.color, modelData.alpha * 0.5], [0.8, modelData.color, modelData.alpha], [1, modelData.color, 0]]
        }
    }

    // Radial wash over the whole rounded panel: `stops` = [[position, colour, alpha], …] (at most 4)
    // out to `reach` px. Four fixed GradientStops, not createObject() in the binding: that made new
    // stops on every change and never freed the old ones (code review 2, ticket 13).
    component Wash: Shape {
        id: wash
        property real centerX
        property real centerY
        property real reach
        property var stops: []
        // the i-th stop; the missing ones repeat the last, which draws nothing new
        function stop(i: int): var {
            const s = stops[Math.min(i, stops.length - 1)] ?? [1, Theme.transparent, 0];
            return { position: s[0], color: Qt.alpha(s[1], s[2]) };
        }
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: wash.centerX
                centerY: wash.centerY
                centerRadius: wash.reach
                focalX: wash.centerX
                focalY: wash.centerY
                GradientStop { position: wash.stop(0).position; color: wash.stop(0).color }
                GradientStop { position: wash.stop(1).position; color: wash.stop(1).color }
                GradientStop { position: wash.stop(2).position; color: wash.stop(2).color }
                GradientStop { position: wash.stop(3).position; color: wash.stop(3).color }
            }
            PathRectangle {
                width: wash.width
                height: wash.height
                radius: backdrop.radius
            }
        }
    }
}
