// theme.js — theme "text", own code (faza C ticket 35, 2026-11-12). spicetify injects it (inject_theme_js = 1).
// Two-colour playback time: the time labels sit over the playback bar, so one colour is unreadable over either the
// fill or the track. Spotify keeps the progress only in the bar's inline style (--progress-bar-transform), and the
// bar is a sibling of the labels, so CSS cannot reach it. This script writes, on each label, --time-fill-x: the
// distance in px from the label's left edge to the fill edge. user.css draws the label text with background-clip:
// text, dark left of that point and light right of it. Without this script the labels keep the light colour.
(function timeSplit() {
    const LABELS = '[data-testid="playback-position"], [data-testid="playback-duration"]';

    function update() {
        const bar = document.querySelector('.playback-bar [data-testid="progress-bar"]');
        if (!bar) return;
        const p = parseFloat(bar.style.getPropertyValue("--progress-bar-transform"));
        if (!Number.isFinite(p)) return;
        const r = bar.getBoundingClientRect();
        const edge = r.left + r.width * p / 100;
        for (const label of document.querySelectorAll(LABELS)) {
            const x = `${(edge - label.getBoundingClientRect().left).toFixed(1)}px`;
            if (label.style.getPropertyValue("--time-fill-x") !== x) label.style.setProperty("--time-fill-x", x);
        }
    }

    // Progress, seeking, a wider time text ("9:59" -> "10:00") and a re-rendered bar all change something under
    // the now-playing bar. Our own --time-fill-x writes are style changes too; update() skips equal values, so the
    // observer settles after one extra call.
    const observer = new MutationObserver(update);
    function attach() {
        const root = document.querySelector(".Root__now-playing-bar");
        if (!root) return setTimeout(attach, 500);
        observer.observe(root, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ["style"] });
        update();
    }
    window.addEventListener("resize", update);
    attach();
})();
