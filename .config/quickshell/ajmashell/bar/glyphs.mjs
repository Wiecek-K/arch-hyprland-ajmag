// Ink boxes (drawn shape) of the Bar icons that sit alone in a round island, and the offset that
// centres that shape in a box (ticket 09, user 2026-10-01: the Wi-Fi icon looked off-centre).
// Qt's FontMetrics.tightBoundingRect returns these Nerd Font icons ~25% too small (Wi-Fi: 12 x 10 px
// instead of 16 x 13 px at 16 px), so the boxes are measured with freetype by
// ~/Projects/hyprland-lua-migration/tools/measure-glyphs.sh — rerun it after changing the font or the icons.
// In em, relative to the pen origin and the baseline (negative = above it).
// A JS module (not QML) so tools/test-bar-glyphs.mjs can test it with node. Own implementation.

export const INK = {
    "\u{f092f}": { left: 0.000, top: -0.720, width: 0.970, height: 0.775 },
    "\u{f091f}": { left: 0.000, top: -0.720, width: 0.970, height: 0.775 },
    "\u{f0922}": { left: 0.000, top: -0.720, width: 0.970, height: 0.775 },
    "\u{f0925}": { left: 0.000, top: -0.720, width: 0.970, height: 0.775 },
    "\u{f0928}": { left: 0.000, top: -0.720, width: 0.970, height: 0.775 },
    "\u{f092e}": { left: 0.000, top: -0.755, width: 0.970, height: 0.840 },
    "\u{f0319}": { left: 0.000, top: -0.795, width: 0.920, height: 0.920 },
    "\u{f0318}": { left: 0.000, top: -0.795, width: 0.920, height: 0.920 },
    "\u{f00af}": { left: 0.050, top: -0.750, width: 0.535, height: 0.835 },
    "\u{f00b3}": { left: 0.050, top: -0.835, width: 0.535, height: 1.005 },
    "\u{f00b1}": { left: 0.000, top: -0.750, width: 0.750, height: 0.835 },
    "\u{f0a2}": { left: 0.000, top: -0.800, width: 0.810, height: 0.930 },
    "\u{f1f7}": { left: 0.000, top: -0.800, width: 1.160, height: 0.930 },
};

// Whole-pixel shift of a Text that shows `glyph` so its ink box's middle lands on the Text box's middle.
// box: { pixelSize, width, height, ascent } — font pixel size, Text size, FontMetrics.ascent.
export function centringOffset(glyph, { pixelSize, width, height, ascent }) {
    const ink = INK[glyph];
    if (!ink)
        return { x: 0, y: 0 };
    const x = (width - ink.width * pixelSize) / 2 - ink.left * pixelSize;
    const middle = ascent + (ink.top + ink.height / 2) * pixelSize; // from the top of the line
    return { x: Math.round(x), y: Math.round(height / 2 - middle) };
}
