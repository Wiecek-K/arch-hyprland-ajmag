// theme.js — theme "text", own code (faza C ticket 35, 2026-11-12). spicetify injects it (inject_theme_js = 1).
// Two-colour playback time: the time labels sit over the playback bar, so one colour is unreadable over either the
// fill or the track. Spotify keeps the progress only in the bar's inline style (--progress-bar-transform), and the
// bar is a sibling of the labels, so CSS cannot reach it. This script writes, on each label, --time-fill-x: the
// distance in px from the label's left edge to the fill edge. user.css draws the label text with background-clip:
// text, dark left of that point and light right of it. Without --time-fill-x a label keeps the light colour.
// The fill has no CSS transition (user.css), so the split jumps together with it.
// Text colour over the fill (user's request 2026-11-13): --spice-main or --spice-text, whichever has the higher
// WCAG contrast with the fill under the label's centre. The fill colour is read from the computed styles: the bar's
// gradient at that point over the backgrounds behind the bar. With the default palette recipe main always wins
// (109 palettes); the check matters for other recipes (scheme, contrast, lightness in Theme Center).
// Keep the selectors in sync with the "Time labels over the bar" rules in user.css.
(function playbackTimeSplit() {
    const LABELS = '.playback-bar [data-testid="playback-position"], .playback-bar [data-testid="playback-duration"]';
    const BAR = '.playback-bar [data-testid="progress-bar"]';

    // "a(...), b(...)" -> ["a(...)", "b(...)"]: split a background-image list at top-level commas.
    function layers(value) {
        const out = []; let depth = 0, start = 0;
        for (let i = 0; i < value.length; i++) {
            if (value[i] === "(") depth++;
            else if (value[i] === ")") depth--;
            else if (value[i] === "," && depth === 0) { out.push(value.slice(start, i)); start = i + 1; }
        }
        out.push(value.slice(start));
        return out.map(v => v.trim()).filter(v => v && v !== "none");
    }
    // Every rgb()/rgba() in a computed value, as [r, g, b, a]; computed styles always use these forms.
    function colours(value) {
        return [...value.matchAll(/rgba?\(([^)]+)\)/g)].map(m => {
            const [r, g, b, a = 1] = m[1].split(",").map(Number);
            return [r, g, b, a];
        });
    }
    const mean = cs => [0, 1, 2, 3].map(i => cs.reduce((sum, c) => sum + c[i], 0) / cs.length);
    const over = (top, below) => [0, 1, 2].map(i => top[i] * top[3] + below[i] * (1 - top[3])).concat(1);
    function luminance([r, g, b]) {
        const lin = v => (v /= 255) <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
    }
    function contrast(a, b) {
        const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
        return (hi + 0.05) / (lo + 0.05);
    }

    // Opaque colour behind `el`: background layers of its ancestors (each layer averaged; the ones here are flat),
    // composited from the first opaque layer up.
    function backdrop(el) {
        const stack = [];
        for (let node = el.parentElement; node; node = node.parentElement) {
            const cs = getComputedStyle(node);
            for (const layer of layers(cs.backgroundImage)) {
                const c = colours(layer);
                if (c.length) stack.push(mean(c));
            }
            const bg = colours(cs.backgroundColor)[0];
            if (bg && bg[3] > 0) stack.push(bg);
            if (stack.length && stack[stack.length - 1][3] >= 1) break;
        }
        let colour = [0, 0, 0, 1];
        for (let i = stack.length - 1; i >= 0; i--) colour = over(stack[i], colour);
        return colour;
    }

    // var(--spice-main) or var(--spice-text) for text over the fill at viewport x.
    function fillTextColour(bar, barRect, x) {
        const stops = colours(getComputedStyle(bar).backgroundImage);
        if (stops.length < 2) return "var(--spice-main)";
        const t = Math.min(1, Math.max(0, (x - barRect.left) / barRect.width));
        const first = stops[0], last = stops[stops.length - 1];
        const fill = over(first.map((v, i) => v + (last[i] - v) * t), backdrop(bar));
        const root = getComputedStyle(document.documentElement);
        const main = colours(`rgb(${root.getPropertyValue("--spice-rgb-main")})`)[0];
        const text = colours(`rgb(${root.getPropertyValue("--spice-rgb-text")})`)[0];
        if (!main || !text) return "var(--spice-main)";
        return contrast(text, fill) > contrast(main, fill) ? "var(--spice-text)" : "var(--spice-main)";
    }

    function set(label, name, value) {
        if (label.style.getPropertyValue(name) !== value) label.style.setProperty(name, value);
    }

    function update() {
        const labels = document.querySelectorAll(LABELS);
        const bar = document.querySelector(BAR);
        const progressPct = bar ? parseFloat(bar.style.getPropertyValue("--progress-bar-transform")) : NaN;
        if (!Number.isFinite(progressPct)) {
            for (const label of labels) {
                label.style.removeProperty("--time-fill-x");
                label.style.removeProperty("--time-fill-colour");
            }
            return;
        }
        const barRect = bar.getBoundingClientRect();
        const fillEdge = barRect.left + barRect.width * progressPct / 100;
        for (const label of labels) {
            const labelRect = label.getBoundingClientRect();
            set(label, "--time-fill-x", `${(fillEdge - labelRect.left).toFixed(1)}px`);
            set(label, "--time-fill-colour", fillTextColour(bar, barRect, labelRect.left + labelRect.width / 2));
        }
    }

    // Progress, seeking, a wider time text ("9:59" -> "10:00", remaining "-1:23") and a re-rendered bar all change
    // something under the now-playing bar. Our own --time-fill-x writes are style changes too; update() skips equal
    // values, so the observer settles after one extra call.
    let root = null;
    const observer = new MutationObserver(() => {
        update();
    });
    function attach() {
        observer.disconnect();
        root = document.querySelector(".Root__now-playing-bar");
        if (!root) return setTimeout(attach, 500);
        observer.observe(root, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ["style"] });
        update();
    }
    window.addEventListener("resize", update);
    // New wallpaper colours: live-colors.js swaps colors.css without a mutation here; re-check when it has loaded.
    document.addEventListener("load", (event) => {
        if (event.target.matches?.("link.userCSS")) update();
    }, true);
    // A detached root gets no more mutations, so the check above may never run: look once every 5 s (one read).
    setInterval(() => { if (root && !root.isConnected) attach(); }, 5000);
    attach();
})();
