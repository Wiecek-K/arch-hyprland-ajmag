// Gradient of the big popups' background (faza E ticket 14, ADR 0021): the drawing only, everything from properties
// and no import of the shell's singletons, so Ajmashell Theme Center loads this file from the Ajmashell directory for
// its look previews (a Loader with a file URL) instead of keeping a copy. In the shell: LookBackground.qml.
// Geometry (line, layers, stops) in gradient.mjs next to it. Every stop keeps the background's alpha (Hyprland's blur
// under the popup stays on); the second corner glow fades to transparent over the full background. Conical layers:
// ticket E16.
// Own implementation, after the throw-away prototype of ticket C10 (ProtoGradientFill.qml).
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "gradient.mjs" as G

Item {
    id: fill

    property var settings: null // the look's gradient {style, a, b, strength, angle, reachA, reachB}; null = nothing
    property color colorA // the colours of the roles settings.a and settings.b
    property color colorB
    property color base // the look's background (role and alpha)
    property real radius: 0 // corners of the box; 0 inside a box that clips them itself

    // colour between a and b at t, with the alpha of a
    function mix(a: color, b: color, t: real): color {
        return Qt.alpha(Qt.tint(Qt.alpha(a, 1), Qt.alpha(b, t)), a.a);
    }

    // a and b pulled towards the background by the strength (strength 1 = the role's own colour)
    readonly property color toneA: mix(base, colorA, settings?.strength ?? 0)
    readonly property color toneB: mix(base, colorB, settings?.strength ?? 0)
    readonly property var colours: ({
            a: toneA,
            b: toneB,
            base: base,
            mid: mix(toneA, toneB, 0.5),
            clear: Qt.alpha(toneB, 0),
            clearA: Qt.alpha(toneA, 0),
            clearBase: Qt.alpha(base, 0)
        })
    readonly property var layers: settings ? G.layers(settings, width, height) : []

    // stop i of a layer's stops, the last one repeated (a ShapePath gradient has a fixed number of GradientStops)
    function stop(stops: var, i: int): var {
        const s = stops[Math.min(i, stops.length - 1)];
        return { position: s[0], color: fill.colours[s[1]] };
    }

    Repeater {
        model: fill.layers.filter(l => l.type === "linear")

        Shape {
            id: linear
            required property var modelData
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: linear.modelData.x1
                    y1: linear.modelData.y1
                    x2: linear.modelData.x2
                    y2: linear.modelData.y2
                    GradientStop { position: fill.stop(linear.modelData.stops, 0).position; color: fill.stop(linear.modelData.stops, 0).color }
                    GradientStop { position: fill.stop(linear.modelData.stops, 1).position; color: fill.stop(linear.modelData.stops, 1).color }
                    GradientStop { position: fill.stop(linear.modelData.stops, 2).position; color: fill.stop(linear.modelData.stops, 2).color }
                    GradientStop { position: fill.stop(linear.modelData.stops, 3).position; color: fill.stop(linear.modelData.stops, 3).color }
                }
                PathRectangle {
                    width: fill.width
                    height: fill.height
                    radius: fill.radius
                }
            }
        }
    }

    Repeater {
        model: fill.layers.filter(l => l.type === "radial")

        Shape {
            id: radial
            required property var modelData
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: radial.modelData.cx
                    centerY: radial.modelData.cy
                    centerRadius: radial.modelData.r
                    focalX: radial.modelData.cx
                    focalY: radial.modelData.cy
                    GradientStop { position: fill.stop(radial.modelData.stops, 0).position; color: fill.stop(radial.modelData.stops, 0).color }
                    GradientStop { position: fill.stop(radial.modelData.stops, 1).position; color: fill.stop(radial.modelData.stops, 1).color }
                }
                PathRectangle {
                    width: fill.width
                    height: fill.height
                    radius: fill.radius
                }
            }
        }
    }

    Repeater {
        // Qt sweeps counter-clockwise from its angle, gradient.mjs clockwise: the stops mirrored (position p → 1 − p)
        model: fill.layers.filter(l => l.type === "conical").map(l => Object.assign({}, l, {
                    stops: l.stops.map(st => [1 - st[0], st[1]]).reverse()
                }))

        Shape {
            id: conical
            required property var modelData
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillGradient: ConicalGradient {
                    centerX: conical.modelData.cx
                    centerY: conical.modelData.cy
                    angle: (360 - conical.modelData.angle) % 360 // Qt turns counter-clockwise, gradient.mjs clockwise
                    GradientStop { position: fill.stop(conical.modelData.stops, 0).position; color: fill.stop(conical.modelData.stops, 0).color }
                    GradientStop { position: fill.stop(conical.modelData.stops, 1).position; color: fill.stop(conical.modelData.stops, 1).color }
                    GradientStop { position: fill.stop(conical.modelData.stops, 2).position; color: fill.stop(conical.modelData.stops, 2).color }
                }
                PathRectangle {
                    width: fill.width
                    height: fill.height
                    radius: fill.radius
                }
            }
        }
    }
}
