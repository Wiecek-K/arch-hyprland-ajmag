// PROTOTYPE, ticket C10 — throwaway. Gradient background of a big popup, drawn under its content
// (z -1: below the panel's own colour, which is transparent while the prototype is on).
// The style and colours come from ProtoGradient; `base` is the look's background of that popup.

import QtQuick
import QtQuick.Shapes
import qs.singletons.protogradient

Item {
    id: fill

    property color base
    property real radius: (parent as Rectangle)?.radius ?? 0 // inside a ClippingRectangle (launcher, Keybinds) the box clips the corners
    readonly property color c1: ProtoGradient.tone(base, ProtoGradient.accentA)
    readonly property color c2: ProtoGradient.tone(base, ProtoGradient.accentB)
    readonly property string key: ProtoGradient.styleKey
    readonly property real diagonal: Math.sqrt(width * width + height * height)
    // direction: the style's own angle turned by ProtoGradient.angle; u = from the centre to where the
    // direction leaves the box, stretched to the corners at 45° (so "ukos" at 0° runs corner to corner)
    readonly property real direction: ((key === "vert" ? 90 : 45) + ProtoGradient.angle) * Math.PI / 180
    readonly property real dx: Math.cos(direction)
    readonly property real dy: Math.sin(direction)
    readonly property real stretch: 1 / Math.max(Math.abs(dx), Math.abs(dy))
    readonly property real ux: dx * stretch * width / 2
    readonly property real uy: dy * stretch * height / 2
    // linear styles: three stops [position, colour] from (centre − u) to (centre + u)
    readonly property var linear: key === "diag" ? [[0, c1], [0.5, ProtoGradient.mix(c1, base, 0.5)], [1, base]]
        : key === "vert" ? [[0, c1], [0.6, base], [1, base]]
        : key === "bands" ? [[0, c1], [0.5, base], [1, c2]]
        : key === "duo" ? [[0, c1], [0.5, ProtoGradient.mix(c1, c2, 0.5)], [1, c2]]
        : null

    anchors.fill: parent
    z: -1
    visible: ProtoGradient.on

    Shape {
        anchors.fill: parent
        visible: fill.linear !== null
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: fill.width / 2 - fill.ux
                y1: fill.height / 2 - fill.uy
                x2: fill.width / 2 + fill.ux
                y2: fill.height / 2 + fill.uy
                GradientStop { position: fill.linear?.[0][0] ?? 0; color: fill.linear?.[0][1] ?? fill.base }
                GradientStop { position: fill.linear?.[1][0] ?? 0.5; color: fill.linear?.[1][1] ?? fill.base }
                GradientStop { position: fill.linear?.[2][0] ?? 1; color: fill.linear?.[2][1] ?? fill.base }
            }
            PathRectangle {
                width: fill.width
                height: fill.height
                radius: fill.radius
            }
        }
    }

    // "róg" and "2 rogi": a glow from the corner at (centre − u) over the background
    Shape {
        anchors.fill: parent
        visible: fill.key === "corner" || fill.key === "corners"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: fill.width / 2 - fill.ux
                centerY: fill.height / 2 - fill.uy
                centerRadius: fill.diagonal * 0.9
                focalX: fill.width / 2 - fill.ux
                focalY: fill.height / 2 - fill.uy
                GradientStop { position: 0; color: fill.c1 }
                GradientStop { position: 1; color: fill.base }
            }
            PathRectangle {
                width: fill.width
                height: fill.height
                radius: fill.radius
            }
        }
    }

    // "2 rogi": a second glow from the opposite corner (centre + u), fading out
    Shape {
        anchors.fill: parent
        visible: fill.key === "corners"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: fill.width / 2 + fill.ux
                centerY: fill.height / 2 + fill.uy
                centerRadius: fill.diagonal * 0.6
                focalX: fill.width / 2 + fill.ux
                focalY: fill.height / 2 + fill.uy
                GradientStop { position: 0; color: fill.c2 }
                GradientStop { position: 1; color: Qt.alpha(fill.c2, 0) }
            }
            PathRectangle {
                width: fill.width
                height: fill.height
                radius: fill.radius
            }
        }
    }
}
