// Geometry of the big popups' background gradient (faza E ticket 14, ADR 0021): the line a style runs along and the
// layers GradientFill.qml draws over it. Pure: the settings come from the look's `gradient` (look-options.json);
// colours are names that GradientFill turns into colours: "a" and "b" (the roles pulled towards the background by the
// strength), "base" (the background), "mid" (half way between a and b), "clear" (b fully transparent), "clearA" (a fully
// transparent). Styles conic … aurora: ticket E16 (prototype; the user keeps some of them).
// Own implementation, after the throw-away prototype of ticket C10 (ProtoGradientFill.qml).
// SPDX-License-Identifier: AGPL-3.0-or-later
// Tests: ~/Projects/hyprland-lua-migration/tools/test-gradient.mjs

// The line through the centre of a w×h box in the direction angle (degrees, 0 = to the right, 90 = down), from edge
// to edge of the box scaled to a square, so 45° runs corner to corner whatever the box's shape.
export function line(angle, w, h) {
    const rad = angle * Math.PI / 180;
    const dx = Math.cos(rad);
    const dy = Math.sin(rad);
    const stretch = 1 / Math.max(Math.abs(dx), Math.abs(dy));
    const ux = dx * stretch * w / 2;
    const uy = dy * stretch * h / 2;
    return { x1: w / 2 - ux, y1: h / 2 - uy, x2: w / 2 + ux, y2: h / 2 + uy };
}

// What to draw for gradient g ({style, angle, reachA, reachB}) in a w×h box at time t (seconds, wall clock; only the
// aurora moves with it, 0 = standing), bottom layer first: [{type: "linear", x1, y1, x2, y2, stops, spread?: "reflect"}
// | {type: "radial", cx, cy, r, fx?, fy? (focal point, default the centre), stops} | {type: "conical", cx, cy, angle
// (degrees, clockwise like g.angle), stops}], stops = [[position 0–1, colour name]].
export function layers(g, w, h, t = 0) {
    const axis = line(g.angle, w, h);
    const snap = v => Math.round(v * 1e6) / 1e6; // a stop's position without float noise (0.35, not 0.35000000000000003)
    const reachA = g.reachA;
    const reachB = g.reachB;
    const linear = stops => [{ type: "linear", x1: axis.x1, y1: axis.y1, x2: axis.x2, y2: axis.y2, stops }];
    switch (g.style) {
    case "linear":
        return linear([[0, "a"], [reachA, "base"], [1, "base"]]);
    case "corner": {
        // glows from the axis' ends, reach = share of the diagonal
        const diagonal = Math.sqrt(w * w + h * h);
        const out = [{ type: "radial", cx: axis.x1, cy: axis.y1, r: reachA * diagonal, stops: [[0, "a"], [1, "base"]] }];
        if (reachB > 0)
            out.push({ type: "radial", cx: axis.x2, cy: axis.y2, r: reachB * diagonal, stops: [[0, "b"], [1, "clear"]] });
        return out;
    }
    case "bands": {
        // overlapping bands meet at one point, shared in proportion to the reaches
        const overlap = reachA + reachB > 1;
        const meet = overlap ? Math.round(reachA / (reachA + reachB) * 1e6) / 1e6 : reachA;
        return linear([[0, "a"], [meet, "base"], [overlap ? meet : 1 - reachB, "base"], [1, "b"]]);
    }
    case "duo":
        return linear([[0, "a"], [reachA, "mid"], [1, "b"]]);
    case "mirror": {
        // symmetric: B over reach A in the middle
        return linear([[0, "a"], [snap((1 - reachA) / 2), "b"], [snap((1 + reachA) / 2), "b"], [1, "a"]]);
    }
    case "glow": {
        // reach = share of the way from the centre to a corner; no angle
        const r = reachA * Math.sqrt(w * w + h * h) / 2;
        return [{ type: "radial", cx: w / 2, cy: h / 2, r, stops: [[0, "a"], [1, "base"]] }];
    }
    case "spotlight": {
        // the focal point at the line's start, the circle pushed in along the line: a beam, brightest at the edge
        const r = reachA * Math.sqrt(w * w + h * h);
        const len = Math.hypot(axis.x2 - axis.x1, axis.y2 - axis.y1);
        const push = 0.6 * r / len;
        return [{
            type: "radial", fx: axis.x1, fy: axis.y1, r, stops: [[0, "a"], [1, "base"]],
            cx: axis.x1 + (axis.x2 - axis.x1) * push, cy: axis.y1 + (axis.y2 - axis.y1) * push
        }];
    }
    case "vignette": {
        // a frame of the same thickness on every side, no angle: A across, then A down over it, see-through between
        const thick = reachA * Math.min(w, h) / 2;
        const sx = snap(thick / w);
        const sy = snap(thick / h);
        return [
            { type: "linear", x1: 0, y1: h / 2, x2: w, y2: h / 2, stops: [[0, "a"], [sx, "base"], [1 - sx, "base"], [1, "a"]] },
            { type: "linear", x1: w / 2, y1: 0, x2: w / 2, y2: h, stops: [[0, "a"], [sy, "clearA"], [1 - sy, "clearA"], [1, "a"]] }
        ];
    }
    case "stripes": {
        // half a stripe of A, then half a gap, from the line's start; the gradient's reflect spread mirrors it onwards,
        // so a stripe and a gap together take reach A of the line (at least 2%)
        const period = Math.max(reachA, 0.02) / 2;
        const edge = reachB / 2;
        return [{
            type: "linear", spread: "reflect",
            x1: axis.x1, y1: axis.y1, x2: axis.x1 + (axis.x2 - axis.x1) * period, y2: axis.y1 + (axis.y2 - axis.y1) * period,
            stops: [[0, "a"], [snap(0.5 - edge), "a"], [snap(0.5 + edge), "base"], [1, "base"]]
        }];
    }
    case "aurora": {
        // soft blobs on an ellipse around the centre, 3/10 of the box out, each turning at its own pace (degrees a
        // second; standing at t = 0); the background under them
        const diagonal = Math.sqrt(w * w + h * h);
        const blob = ([offset, pace, size, colour, clear]) => {
            const rad = (g.angle + offset + pace * t) * Math.PI / 180;
            return {
                type: "radial", cx: w / 2 + Math.cos(rad) * w * 0.3, cy: h / 2 + Math.sin(rad) * h * 0.3,
                r: size * reachA * diagonal, stops: [[0, colour], [1, clear]]
            };
        };
        return [
            { type: "linear", x1: 0, y1: 0, x2: w, y2: 0, stops: [[0, "base"], [1, "base"]] },
            ...[[0, 3, 0.6, "a", "clearA"], [140, -2, 0.5, "b", "clear"], [250, 1.5, 0.4, "a", "clearA"]].map(blob)
        ];
    }
    case "conic":
        // a turn around the centre from the angle (clockwise), back to A where it started
        return [{ type: "conical", cx: w / 2, cy: h / 2, angle: g.angle, stops: [[0, "a"], [reachA, "b"], [1, "a"]] }];
    default:
        return [];
    }
}
