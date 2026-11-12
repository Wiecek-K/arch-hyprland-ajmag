// theme.js — theme "text", own code (faza C ticket 35, 2026-11-12). spicetify injects it (inject_theme_js = 1).
// Two-colour playback time: the time labels sit over the playback bar, so one colour is unreadable over either the
// fill or the track. Spotify keeps the progress only in the bar's inline style (--progress-bar-transform), and the
// bar is a sibling of the labels, so CSS cannot reach it. This script writes, on each label, --time-fill-x: the
// distance in px from the label's left edge to the fill edge. user.css draws the label text with background-clip:
// text, dark left of that point and light right of it. Without --time-fill-x a label keeps the light colour.
// The fill has no CSS transition (user.css), so the split jumps together with it.
// Keep the selectors in sync with the "Time labels over the bar" rules in user.css.
(function playbackTimeSplit() {
    const LABELS = '.playback-bar [data-testid="playback-position"], .playback-bar [data-testid="playback-duration"]';
    const BAR = '.playback-bar [data-testid="progress-bar"]';

    function update() {
        const labels = document.querySelectorAll(LABELS);
        const bar = document.querySelector(BAR);
        const progressPct = bar ? parseFloat(bar.style.getPropertyValue("--progress-bar-transform")) : NaN;
        if (!Number.isFinite(progressPct)) {
            for (const label of labels) label.style.removeProperty("--time-fill-x");
            return;
        }
        const barRect = bar.getBoundingClientRect();
        const fillEdge = barRect.left + barRect.width * progressPct / 100;
        for (const label of labels) {
            const x = `${(fillEdge - label.getBoundingClientRect().left).toFixed(1)}px`;
            if (label.style.getPropertyValue("--time-fill-x") !== x) label.style.setProperty("--time-fill-x", x);
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
    // A detached root gets no more mutations, so the check above may never run: look once every 5 s (one read).
    setInterval(() => { if (root && !root.isConnected) attach(); }, 5000);
    attach();
})();
