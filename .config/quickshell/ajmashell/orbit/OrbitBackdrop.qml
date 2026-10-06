// TEMPORARY (ticket 13, user 2026-10-06: "the background is boring"): background variants of the
// Orbita to compare, switched with B while it is open. A variant is a set of layers drawn over the
// flat Theme.orbit.background, under the nodes. Remove the variants the user rejects; keep the
// chosen one in Theme.orbit. Own code, no donor.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.singletons.theme

Item {
    id: backdrop

    property int variant: 0 // index in variants
    property real angle: 0 // the orbit's turn, rad
    property real coreRadius: 0 // px, for the halo
    readonly property var variants: [
        { name: "flat", layers: [] },
        { name: "nebula", layers: ["nebula"] },
        { name: "aurora", layers: ["aurora"] },
        { name: "stars", layers: ["stars"] },
        { name: "nebula + stars", layers: ["nebula", "stars"] },
        { name: "aurora + stars", layers: ["aurora", "stars"] },
        { name: "flare", layers: ["flare", "streak"] },
        { name: "flare + stars", layers: ["flare", "stars"] },
        { name: "flare + stars, soft streak", layers: ["flare", "softStreak", "stars"] },
        { name: "halo", layers: ["halo"] },
        { name: "mesh", layers: ["mesh"] },
        { name: "spotlight", layers: ["nebula", "vignette"] },
        { name: "constellation", layers: ["stars", "lines"] }
    ]
    readonly property string name: variants[variant].name
    readonly property var layers: variants[variant].layers
    property real radius: Theme.radius.lg // corners of the panel it fills
    // the orbit's centre: the field above the tab row
    readonly property real cx: width / 2
    readonly property real cy: height / 2 - Theme.orbit.tabHeight / 2

    function has(layer: string): bool {
        return layers.includes(layer);
    }

    // nebula: a soft glow of the accent around the core, fading to the edges
    Wash {
        visible: backdrop.has("nebula")
        centerX: backdrop.cx
        centerY: backdrop.cy
        reach: backdrop.width * 0.55
        stops: [[0, Theme.orbit.backdropGlow, 0.45], [0.45, Theme.orbit.backdropAccent, 0.18], [1, Theme.orbit.backdropGlow, 0]]
    }

    // halo: a ring of light just outside the core
    Wash {
        visible: backdrop.has("halo")
        centerX: backdrop.cx
        centerY: backdrop.cy
        reach: backdrop.coreRadius * 2.2
        stops: [[0, Theme.orbit.backdropGlow, 0], [0.42, Theme.orbit.backdropGlow, 0], [0.5, Theme.orbit.backdropGlow, 0.5], [0.62, Theme.orbit.backdropAccent, 0.18], [1, Theme.orbit.backdropAccent, 0]]
    }

    // mesh: three blurred patches of colour in different corners
    Wash {
        visible: backdrop.has("mesh")
        centerX: backdrop.width * 0.2
        centerY: backdrop.height * 0.25
        reach: backdrop.width * 0.5
        stops: [[0, Theme.orbit.backdropGlow, 0.4], [1, Theme.orbit.backdropGlow, 0]]
    }
    Wash {
        visible: backdrop.has("mesh")
        centerX: backdrop.width * 0.85
        centerY: backdrop.height * 0.8
        reach: backdrop.width * 0.5
        stops: [[0, Theme.orbit.backdropAccent, 0.4], [1, Theme.orbit.backdropAccent, 0]]
    }
    Wash {
        visible: backdrop.has("mesh")
        centerX: backdrop.width * 0.8
        centerY: backdrop.height * 0.1
        reach: backdrop.width * 0.3
        stops: [[0, Theme.orbit.backdropGhost, 0.3], [1, Theme.orbit.backdropGhost, 0]]
    }

    // vignette: darker edges, the eye goes to the core
    Wash {
        visible: backdrop.has("vignette")
        centerX: backdrop.cx
        centerY: backdrop.cy
        reach: Math.hypot(backdrop.width, backdrop.height) / 2
        stops: [[0, Theme.orbit.backdropShade, 0], [0.55, Theme.orbit.backdropShade, 0], [1, Theme.orbit.backdropShade, 0.55]]
    }

    // aurora: a diagonal wash from the accent to the tertiary colour
    Shape {
        anchors.fill: parent
        visible: backdrop.has("aurora")
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

    // stars (and constellation lines): fixed dots that turn slowly with the orbit (a third of its speed)
    Item {
        anchors.fill: parent
        visible: backdrop.has("stars")
        clip: true

        Item {
            id: sky
            anchors.centerIn: parent
            width: Math.hypot(backdrop.width, backdrop.height)
            height: width
            rotation: backdrop.angle * 180 / Math.PI / 3
            readonly property var stars: backdrop.has("stars") ? backdrop.makeStars(90) : []

            // each star joined to its nearest neighbour (and the second one when close), painted once
            Canvas {
                anchors.fill: parent
                visible: backdrop.has("lines")
                onVisibleChanged: if (visible) requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = Theme.orbit.backdropStar;
                    ctx.globalAlpha = 0.18;
                    ctx.lineWidth = 1;
                    const stars = sky.stars.map(star => ({ x: star.x * width, y: star.y * height }));
                    for (const star of stars) {
                        const near = stars.filter(other => other !== star)
                            .map(other => ({ other, d: Math.hypot(other.x - star.x, other.y - star.y) }))
                            .sort((a, b) => a.d - b.d);
                        for (const [k, link] of near.slice(0, 2).entries()) {
                            if (k > 0 && link.d > width * 0.09)
                                break;
                            ctx.beginPath();
                            ctx.moveTo(star.x, star.y);
                            ctx.lineTo(link.other.x, link.other.y);
                            ctx.stroke();
                        }
                    }
                }
            }

            Repeater {
                model: sky.stars

                Rectangle {
                    required property var modelData
                    x: modelData.x * sky.width - width / 2
                    y: modelData.y * sky.height - height / 2
                    width: modelData.size
                    height: width
                    radius: width / 2
                    color: Theme.orbit.backdropStar
                    opacity: modelData.alpha
                }
            }
        }
    }

    // flare: a bright source drifting round the edge, an anamorphic streak through it and a row of
    // ghosts on the far side of the centre, like a camera lens looking at a light
    Item {
        id: flare
        anchors.fill: parent
        visible: backdrop.has("flare")
        clip: true
        // the source turns round the centre, one lap per two orbit laps
        readonly property real theta: backdrop.angle / 2 - 2.3
        readonly property real sx: backdrop.cx + Math.cos(theta) * backdrop.width * 0.42
        readonly property real sy: backdrop.cy + Math.sin(theta) * backdrop.height * 0.42
        // point at `t` along the axis from the source through the centre (t = 1: centre)
        function axisX(t: real): real {
            return sx + (backdrop.cx - sx) * t;
        }
        function axisY(t: real): real {
            return sy + (backdrop.cy - sy) * t;
        }

        // glow of the source
        Wash {
            centerX: flare.sx
            centerY: flare.sy
            reach: 140
            stops: [[0, Theme.orbit.backdropFlare, 0.7], [0.12, Theme.orbit.backdropFlare, 0.35], [0.4, Theme.orbit.backdropGlow, 0.15], [1, Theme.orbit.backdropGlow, 0]]
        }

        // anamorphic streak: a wide soft band and a thin bright line through the source
        Streak {
            visible: backdrop.has("streak")
            centerY: flare.sy
            thickness: 26
            peak: 0.12
        }
        Streak {
            visible: backdrop.has("streak")
            centerY: flare.sy
            thickness: 3
            peak: 0.5
        }

        // the same streak with no edges: a radial glow squashed into a thin ellipse, so it fades
        // smoothly up, down and to the sides (user, 2026-10-06: the band's edges were too sharp)
        Item {
            anchors.fill: parent
            visible: backdrop.has("softStreak")

            Wash {
                // a square around the source, squashed vertically to the band's height
                anchors.fill: undefined
                x: flare.sx - backdrop.width * 0.9
                y: flare.sy - backdrop.width * 0.9
                width: backdrop.width * 1.8
                height: width
                centerX: width / 2
                centerY: height / 2
                reach: width / 2
                rounded: false
                stops: [[0, Theme.orbit.backdropFlare, 0.45], [0.08, Theme.orbit.backdropFlare, 0.22], [0.35, Theme.orbit.backdropFlare, 0.07], [1, Theme.orbit.backdropFlare, 0]]
                transform: Scale {
                    origin.x: backdrop.width * 0.9
                    origin.y: backdrop.width * 0.9
                    yScale: 0.035
                }
            }
        }

        // ghosts on the far side of the centre
        Repeater {
            model: [
                { t: 0.55, size: 26, color: Theme.orbit.backdropGhost, alpha: 0.22 },
                { t: 1.35, size: 70, color: Theme.orbit.backdropGlow, alpha: 0.12 },
                { t: 1.6, size: 18, color: Theme.orbit.backdropFlare, alpha: 0.3 },
                { t: 1.85, size: 110, color: Theme.orbit.backdropAccent, alpha: 0.1 },
                { t: 2.15, size: 40, color: Theme.orbit.backdropGhost, alpha: 0.18 }
            ]

            Wash {
                required property var modelData
                centerX: flare.axisX(modelData.t)
                centerY: flare.axisY(modelData.t)
                reach: modelData.size
                // a ghost has a brighter rim, like an aperture reflection
                stops: [[0, modelData.color, modelData.alpha * 0.5], [0.8, modelData.color, modelData.alpha], [1, modelData.color, 0]]
            }
        }
    }

    // `count` stars at fixed pseudo-random places (same every time): { x, y } in 0 … 1, size px, alpha
    function makeStars(count: int): var {
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

    // Radial wash over the whole rounded panel: `stops` = [[position, colour, alpha], …] out to `reach` px.
    component Wash: Shape {
        id: wash
        property real centerX
        property real centerY
        property real reach
        property var stops: []
        property bool rounded: true // clipped to the panel's rounded corners
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
                stops: wash.stops.map(stop => gradientStop.createObject(wash, { position: stop[0], color: Qt.alpha(stop[1], stop[2]) }))
            }
            PathRectangle {
                width: wash.width
                height: wash.height
                radius: wash.rounded ? backdrop.radius : 0
            }
        }
    }

    // Horizontal band across the panel, brightest at the flare's source.
    component Streak: Shape {
        id: streak
        property real centerY
        property real thickness
        property real peak
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0
                x2: streak.width
                y1: 0
                y2: 0
                GradientStop { position: 0; color: Theme.transparent }
                GradientStop { position: Math.max(0.01, Math.min(0.99, flare.sx / streak.width)); color: Qt.alpha(Theme.orbit.backdropFlare, streak.peak) }
                GradientStop { position: 1; color: Theme.transparent }
            }
            PathRectangle {
                y: streak.centerY - streak.thickness / 2
                width: streak.width
                height: streak.thickness
                radius: streak.thickness / 2
            }
        }
    }

    Component {
        id: gradientStop
        GradientStop {}
    }
}
