// PROTOTYPE, ticket C10 (gradient in the big popups' backgrounds) — throwaway, not production code.
// Question: which gradient style and which matugen colour pair the big popups should get.
// Picked in the Centrum sterowania (line "Gradient" under "Look") or over IPC:
// `qs -c ajmashell ipc call gradient set STYLE PALETTE STRENGTH ANGLE` (indexes, 0–1, degrees), `... gradient state`.
// Every stop keeps the alpha of the look's background (Look.background), so Hyprland's blur stays on.
// Kept on the dotfiles branch prototype/ticket-c10-gradient once a variant is picked.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.singletons.theme

Singleton {
    id: root

    readonly property var styles: [
        { key: "off", label: "brak" },
        { key: "diag", label: "ukos" },
        { key: "vert", label: "pion" },
        { key: "corner", label: "róg" },
        { key: "corners", label: "2 rogi" },
        { key: "bands", label: "pasma" },
        { key: "duo", label: "dwukolor" }
    ]
    // [first, second] matugen roles
    readonly property var palettes: [
        { label: "prim → ter", a: "primary_container", b: "tertiary_container" },
        { label: "sec → prim", a: "secondary_container", b: "primary_container" },
        { label: "ter → sec", a: "tertiary_container", b: "secondary_container" },
        { label: "fixed var", a: "on_primary_fixed_variant", b: "on_tertiary_fixed_variant" },
        { label: "akcenty", a: "primary", b: "tertiary" },
        { label: "neutral", a: "surface_container_highest", b: "surface_container_lowest" }
    ]
    property int style: 1
    property int palette: 0
    property real strength: 0.6 // 0–1: how far the accent goes into the background
    property real angle: 0 // degrees, turns the style's direction clockwise

    readonly property bool on: style > 0
    readonly property string styleKey: styles[style].key
    readonly property color accentA: Theme.colors[palettes[palette].a]
    readonly property color accentB: Theme.colors[palettes[palette].b]

    // colour between a and b at t, alpha of a
    function mix(a: color, b: color, t: real): color {
        return Qt.alpha(Qt.tint(Qt.alpha(a, 1), Qt.alpha(b, t)), a.a);
    }
    // the accent pulled towards the background by the strength, with the background's alpha
    function tone(base: color, accent: color): color {
        return mix(base, accent, strength);
    }

    IpcHandler {
        target: "gradient"

        function set(style: int, palette: int, strength: real, angle: real): void {
            root.style = Math.max(0, Math.min(style, root.styles.length - 1));
            root.palette = Math.max(0, Math.min(palette, root.palettes.length - 1));
            root.strength = Math.max(0, Math.min(strength, 1));
            root.angle = ((angle % 360) + 360) % 360;
        }

        function state(): string {
            return root.styles[root.style].label + " | " + root.palettes[root.palette].a + " → " + root.palettes[root.palette].b + " | " + root.strength.toFixed(2) + " | " + Math.round(root.angle) + "°";
        }
    }
}
