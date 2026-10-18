// Mouse-wheel notches for the Bar islands (workspaces, volume): touchpad deltas add up to whole steps.
// A JS module (not QML) so the tools/test-bar-*.mjs tests can run it with node.
// Idea from DankMaterialShell Modules/DankBar/Widgets/WorkspaceSwitcher.qml (threshold 120, rest dropped after a step):
// https://github.com/AvengeMedia/DankMaterialShell@9dc5b2c5af7d18b7231f425fe0d8fa7243233109
// Own implementation (moved from workspaces.mjs in ticket 08a).

const WHEEL_STEP = 120; // one mouse-wheel notch in angleDelta units

// rest: angleDelta.y collected so far (touchpads send small deltas); delta: this event's angleDelta.y.
// Returns the new rest and the step: 1 = next, -1 = previous, 0 = not a full notch yet. Up = next / louder, like Waybar.
// A fast spin of several notches gives one step per event, the rest is dropped.
export function wheel(rest, delta) {
    const sum = Math.sign(rest) === -Math.sign(delta) ? delta : rest + delta;
    if (Math.abs(sum) < WHEEL_STEP)
        return { rest: sum, step: 0 };
    return { rest: 0, step: sum > 0 ? 1 : -1 };
}
