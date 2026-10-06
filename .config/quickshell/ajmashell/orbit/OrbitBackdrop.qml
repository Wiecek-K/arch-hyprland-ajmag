// TEMPORARY (ticket 13, user 2026-10-06: "the background is boring"): background variants of the
// Orbita to compare, switched with B while it is open. Drawn over the flat Theme.orbit.background,
// under the nodes. Remove the variants the user rejects; keep the chosen one in Theme.orbit.
// Own code, no donor.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.singletons.theme

Item {
    id: backdrop

    property int variant: 0 // index in names
    property real angle: 0 // the orbit's turn, rad
    readonly property var names: ["flat", "nebula", "aurora", "stars", "radar"]
    readonly property string name: names[variant]
    readonly property real radius: Theme.radius.lg

    // nebula: a soft glow of the accent around the core, fading to the edges
    Shape {
        anchors.fill: parent
        visible: backdrop.name === "nebula"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: backdrop.width / 2
                centerY: backdrop.height / 2 - Theme.orbit.tabHeight / 2
                centerRadius: backdrop.width * 0.55
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0; color: Qt.alpha(Theme.orbit.backdropGlow, 0.45) }
                GradientStop { position: 0.45; color: Qt.alpha(Theme.orbit.backdropAccent, 0.18) }
                GradientStop { position: 1; color: Theme.transparent }
            }
            PathRectangle {
                width: backdrop.width
                height: backdrop.height
                radius: backdrop.radius
            }
        }
    }

    // aurora: a diagonal wash from the accent to the tertiary colour
    Shape {
        anchors.fill: parent
        visible: backdrop.name === "aurora"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: backdrop.width
                y2: backdrop.height
                GradientStop { position: 0; color: Qt.alpha(Theme.orbit.backdropGlow, 0.35) }
                GradientStop { position: 0.5; color: Theme.transparent }
                GradientStop { position: 1; color: Qt.alpha(Theme.orbit.backdropAccent, 0.35) }
            }
            PathRectangle {
                width: backdrop.width
                height: backdrop.height
                radius: backdrop.radius
            }
        }
    }

    // stars: fixed dots that turn slowly with the orbit (a third of its speed)
    Item {
        anchors.fill: parent
        visible: backdrop.name === "stars"
        clip: true

        Item {
            anchors.centerIn: parent
            width: Math.hypot(backdrop.width, backdrop.height)
            height: width
            rotation: backdrop.angle * 180 / Math.PI / 3

            Repeater {
                model: backdrop.name === "stars" ? backdrop.stars(90) : []

                Rectangle {
                    required property var modelData
                    x: modelData.x * parent.width
                    y: modelData.y * parent.height
                    width: modelData.size
                    height: width
                    radius: width / 2
                    color: Theme.orbit.backdropStar
                    opacity: modelData.alpha
                }
            }
        }
    }

    // radar: a cone of the accent sweeping round with the orbit
    Shape {
        anchors.fill: parent
        visible: backdrop.name === "radar"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: ConicalGradient {
                centerX: backdrop.width / 2
                centerY: backdrop.height / 2 - Theme.orbit.tabHeight / 2
                angle: -backdrop.angle * 180 / Math.PI * 4
                GradientStop { position: 0; color: Qt.alpha(Theme.orbit.backdropGlow, 0.35) }
                GradientStop { position: 0.18; color: Theme.transparent }
                GradientStop { position: 1; color: Theme.transparent }
            }
            PathRectangle {
                width: backdrop.width
                height: backdrop.height
                radius: backdrop.radius
            }
        }
    }

    // `count` stars at fixed pseudo-random places (same every time): { x, y } in 0 … 1, size px, alpha
    function stars(count: int): var {
        let seed = 1013904223;
        const next = () => {
            seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
            return seed / 4294967296;
        };
        const list = [];
        for (let i = 0; i < count; i++)
            list.push({ x: next(), y: next(), size: next() < 0.85 ? 2 : 3, alpha: 0.25 + 0.5 * next() });
        return list;
    }
}
