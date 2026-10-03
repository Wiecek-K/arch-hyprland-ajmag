// Pure logic of the wallpaper carousel (ticket 19): filters, order, card geometry of the four trial styles.
// Card sizes from serpantinum src/quickshell/wallpaper/WallpaperPicker.qml (delegate cellWidth/targetWidth/targetHeight):
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// Copyright (C) 2026 Illia Miroshnichenko — AGPL-3.0-or-later
// Changes: no History/Video/Search filters (parked, plan D9); geometry as pure functions of one animated
// position (no ListView: its highlight animation has its own fixed curve and fought the card resize); neighbours
// tuck slightly under each other (`overlap`) instead of leaving a gap (user, 2026-10-01).
// SPDX-License-Identifier: AGPL-3.0-or-later
// Tests: ~/Projects/hyprland-lua-migration/tools/test-wallpaper-carousel.mjs

// Order of the "All" tab and of the filter row (serpantinum; Orange + Yellow merged into Amber, user 2026-10-01)
export const BUCKETS = ["Red", "Amber", "Green", "Blue", "Purple", "Pink", "Monochrome"];
export const FILTERS = ["All", ...BUCKETS];

// Sheared cards, serpantinum's skewFactor (style chosen by the user on 2026-10-01 out of four trials)
export const SKEW = -0.35;

// items: index.json items; "All" = by bucket order, then by name; a colour = only that bucket
export function visibleItems(items, filter) {
    const rank = b => {
        const i = BUCKETS.indexOf(b);
        return i < 0 ? BUCKETS.length : i;
    };
    const list = filter === "All" ? items.slice() : items.filter(i => i.bucket === filter);
    return list.sort((a, b) => rank(a.bucket) - rank(b.bucket) || a.fileName.localeCompare(b.fileName));
}

// next filter in `step` direction, skipping colours with no wallpaper in `items` (when given)
export function stepFilter(filter, step, items) {
    const n = FILTERS.length;
    let i = Math.max(0, FILTERS.indexOf(filter));
    for (let k = 0; k < n; k++) {
        i = (((i + step) % n) + n) % n;
        const f = FILTERS[i];
        if (!items || f === "All" || items.some(it => it.bucket === f))
            return f;
    }
    return "All";
}

// index of the current wallpaper in the list, else 0
export function indexOfPath(list, path) {
    const i = list.findIndex(it => it.path === path);
    return i < 0 ? 0 : i;
}

// Geometry of one card.
// offset: signed distance from the current card (0 = current); itemWidth/itemHeight: serpantinum's base sizes;
// overlap: px each card tucks under its neighbour (its cell is narrower than the card).
// width/height: the drawn card; cell: room it takes in the ListView.
export function cardGeometry(offset, itemWidth, itemHeight, overlap = 0) {
    const dist = Math.abs(offset);
    const current = dist === 0;
    // serpantinum: the current card 1.5× wide, neighbours shrink with distance
    const sideScale = Math.max(0.58, Math.pow(0.88, Math.max(0, dist - 1)));
    const width = current ? itemWidth * 1.5 : itemWidth * 0.48 * sideScale;
    const height = current ? itemHeight + 30 : itemHeight * Math.max(0.62, Math.pow(0.9, Math.max(0, dist - 1)));
    return { width, height, cell: Math.max(0, width - overlap) };
}

// Geometry at a fractional offset (the carousel position is animated as one real number):
// linear blend of the two nearest whole offsets, so sizes change continuously while sliding.
export function geometryAt(offset, itemWidth, itemHeight, overlap = 0) {
    const d = Math.abs(offset);
    const lo = Math.floor(d), t = d - lo;
    const a = cardGeometry(lo, itemWidth, itemHeight, overlap);
    if (t === 0)
        return a;
    const b = cardGeometry(lo + 1, itemWidth, itemHeight, overlap);
    const mix = k => a[k] + (b[k] - a[k]) * t;
    return { width: mix("width"), height: mix("height"), cell: mix("cell") };
}

// Layout of the whole strip for carousel position `pos` (0 … count-1, fractional while sliding).
// cards[i].x: left edge of card i's cell; centre: x of the point that must sit in the middle of the view —
// the centre of the current card at whole positions, moving linearly to the next card's centre in between.
export function layout(count, pos, itemWidth, itemHeight, overlap = 0) {
    const cards = [];
    let x = 0;
    for (let i = 0; i < count; i++) {
        const g = geometryAt(i - pos, itemWidth, itemHeight, overlap);
        cards.push({ x, width: g.width, height: g.height, cell: g.cell });
        x += g.cell;
    }
    if (count === 0)
        return { cards, centre: 0 };
    const p = Math.min(Math.max(pos, 0), count - 1);
    const lo = Math.floor(p), t = p - lo;
    const mid = i => cards[i].x + cards[i].cell / 2;
    const centre = t === 0 || lo + 1 >= count ? mid(lo) : mid(lo) + (mid(lo + 1) - mid(lo)) * t;
    return { cards, centre };
}
