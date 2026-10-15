// live-colors.js — Spicetify extension (own code, ticket 49, 2026-10-15): new wallpaper colours without reloading Spotify.
// spicetify-apply.sh (matugen post_hook) runs `spicetify refresh -s`, which rewrites colors.css, and then sends
// Ctrl+Shift+F12 to the Spotify window with hl.dsp.send_shortcut (no focus change). Loading that one stylesheet again
// replaces every --spice-* variable in a few hundred ms; Ctrl+Shift+R reloaded the whole page and showed an empty
// window for ~1 s. `link.userCSS` is added by spicetify itself, so it does not depend on Spotify's hashed class names.
(function liveColors() {
    window.addEventListener("keydown", (event) => {
        if (!(event.ctrlKey && event.shiftKey && !event.altKey && !event.metaKey && event.key === "F12")) return;
        event.preventDefault();
        event.stopPropagation();
        const link = document.querySelector('link.userCSS[href^="colors.css"]');
        // ?t= makes Chromium read the file again instead of reusing the cached stylesheet
        if (link) link.href = `colors.css?t=${Date.now()}`;
    }, true);
})();
