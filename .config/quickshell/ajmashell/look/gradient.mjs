// Geometry of the big popups' background gradient (faza E ticket 14, ADR 0021): the line a style runs along and the
// layers GradientFill.qml draws over it. Pure: the settings come from the look's `gradient` (look-options.json);
// colours are names that GradientFill turns into colours: "a" and "b" (the roles pulled towards the background by the
// strength), "base" (the background), "mid" (half way between a and b), "clear" (b fully transparent).
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
// [{type: "linear", x1, y1, x2, y2, stops} | {type: "radial", cx, cy, r, stops}], stops = [[position 0–1, colour name]].
export function layers(g, w, h) {
    const axis = line(g.angle, w, h);
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
    default:
        return [];
    }
}
