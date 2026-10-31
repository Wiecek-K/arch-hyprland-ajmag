// Geometry of the big popups' background gradient (faza E ticket 14, ADR 0021): the line a style runs along and the
// layers GradientFill.qml draws over it. Pure: the settings come from the look's `gradient` (look-options.json);
// colours are names that GradientFill turns into colours: "a" and "b" (the roles pulled towards the background by the
// strength), "base" (the background), "mid" (half way between a and b), "clear" (b fully transparent), "clearA" (a fully
// transparent), "clearBase" (the background fully transparent). Styles mirror, glow, conic, vignette and
// inverseVignette: ticket E16.
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

// What to draw for gradient g ({style, angle, reachA, reachB}) in a w×h box, bottom layer first:
// [{type: "linear", x1, y1, x2, y2, stops} | {type: "radial", cx, cy, r, stops}
// | {type: "conical", cx, cy, angle (degrees, clockwise like g.angle), stops}], stops = [[position 0–1, colour name]].
export function layers(g, w, h) {
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
    case "vignette":
    case "inverseVignette": {
        // a frame of the same thickness on every side, no angle: across, then down over it, see-through between;
        // vignette = A at the edges, inverse = the plain background at the edges and A in the middle
        const thick = reachA * Math.min(w, h) / 2;
        const sx = snap(thick / w);
        const sy = snap(thick / h);
        const [edge, middle, clear] = g.style === "vignette" ? ["a", "base", "clearA"] : ["base", "a", "clearBase"];
        return [
            { type: "linear", x1: 0, y1: h / 2, x2: w, y2: h / 2, stops: [[0, edge], [sx, middle], [1 - sx, middle], [1, edge]] },
            { type: "linear", x1: w / 2, y1: 0, x2: w / 2, y2: h, stops: [[0, edge], [sy, clear], [1 - sy, clear], [1, edge]] }
        ];
    }
    case "conic":
        // a turn around the centre from the angle (clockwise), back to A where it started
        return [{ type: "conical", cx: w / 2, cy: h / 2, angle: g.angle, stops: [[0, "a"], [reachA, "b"], [1, "a"]] }];
    default:
        return [];
    }
}
