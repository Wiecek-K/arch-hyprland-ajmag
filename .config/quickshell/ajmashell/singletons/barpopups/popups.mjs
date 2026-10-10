// Pure logic of switching between the elements the Bar opens (ticket 27): Orbita, audio popup, tray menu,
// media popup, Centrum sterowania. Their focus grabs let clicks through to the Bar, so one click on another
// island closes the open element and opens the next; a press on one of the element's own islands leaves it to
// that island's toggle (a second click still closes it, the Orbita switches its tab without closing).
// Used by BarPopups.qml and BarPressCloser.qml next to it.
// A JS module (not QML) so tools/test-bar-popups.mjs can test it with node.
// Own implementation.

// The nearest item from `item` up its parents for which `test` is true, or null.
export function findUp(item, test) {
    for (let i = item; i; i = i.parent) {
        if (test(i))
            return i;
    }
    return null;
}

// true when `item` is `owner` or one of its children.
export function within(item, owner) {
    return owner ? findUp(item, i => i === owner) !== null : false;
}

// true for a press on a bell (any Bar, bar/Bell.qml `isBell`): the Centrum sterowania's own island.
export function onBell(hit) {
    return findUp(hit, i => i.isBell === true) !== null;
}

// Whether a press on the Bar on `hit` (null = nothing) closes an element whose own islands are `owners`:
// a list of islands, or a test on the hit item (the Centrum: onBell).
export function closesOn(hit, owners) {
    return typeof owners === "function" ? !owners(hit) : !owners.some(owner => within(hit, owner));
}

// The deepest item under (x, y) in `root`'s coordinates; `childAt(item, x, y)` as Item.childAt.
export function deepestAt(root, x, y, childAt) {
    let item = root;
    for (let child = childAt(item, x, y); child; child = childAt(item, x, y)) {
        x -= child.x;
        y -= child.y;
        item = child;
    }
    return item;
}
