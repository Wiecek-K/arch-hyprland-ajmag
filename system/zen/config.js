// Firefox skips the first line of an autoconfig file — keep this comment.
//
// Zen Browser: live matugen colours without a browser restart (Ajmashell ticket 48).
// Installed as /opt/zen-browser-bin/config.js, loaded by defaults/pref/autoconfig.js (see install.sh, section Zen).
//
// Why: Firefox reads userChrome.css (and its @import "matugen-colors.css") only at startup. This script watches
// <profile>/chrome/matugen-colors.css and registers its content as a user style sheet each time matugen rewrites it.
// When: once per Zen process, from "final-ui-startup"; the sheet service covers every window. The file is checked
// every POLL_MS and applied when its mtime is the same on two checks in a row (matugen has finished writing).
// The variables get !important so they win over the startup copy from userChrome.css (same user origin).
// Kept here, in root-owned /opt, not in a profile script: any user process can write the profile.
// Own implementation on the documented AutoConfig / nsIStyleSheetService API (provenance: pochodzenie-komponentow.md
// in the hyprland-lua-migration project, ADR 0015).
// Roll back: sudo rm /opt/zen-browser-bin/config.js /opt/zen-browser-bin/defaults/pref/autoconfig.js, restart Zen
// (colours then change only after a restart, as before). Log: Browser Console (Ctrl+Shift+J), filter "ajmashell-zen".
try {
  const { classes: Cc, interfaces: Ci, utils: Cu } = Components;
  const sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(Ci.nsIStyleSheetService);
  const TYPE = sss.USER_SHEET;
  const POLL_MS = 500;
  // A custom property declaration up to its ";" or "}", without one that already has !important.
  const VARIABLE = /(--[\w-]+\s*:\s*[^;!{}]*[^;!{}\s])(?=\s*[;}])/g;

  const log = msg => Services.console.logStringMessage("[ajmashell-zen] " + msg);

  let registered = null;
  let registeredCss = null;
  let applied = 0;
  let pending = 0;

  const colorsFile = () => {
    const f = Services.dirsvc.get("ProfD", Ci.nsIFile);
    f.append("chrome");
    f.append("matugen-colors.css");
    return f;
  };

  // null when the file is missing.
  const modified = () => {
    try {
      return colorsFile().lastModifiedTime;
    } catch (e) {
      return null;
    }
  };

  // Register the new sheet first and drop the old one after: no frame without the colour variables (no blink).
  // An empty or broken file (no variables) keeps the sheet that works.
  const load = mtime => {
    let css;
    try {
      css = Cu.readUTF8File(colorsFile());
    } catch (e) {
      log("cannot read colours: " + e);
      return;
    }
    let count = 0;
    css = css.replace(VARIABLE, decl => {
      count++;
      return decl + " !important";
    });
    if (count === 0) {
      log("skipped, no colour variables in the file, mtime " + mtime);
      return;
    }
    if (css === registeredCss) {
      return;
    }
    const uri = Services.io.newURI("data:text/css;charset=utf-8," + encodeURIComponent(css));
    sss.loadAndRegisterSheet(uri, TYPE);
    if (registered && sss.sheetRegistered(registered, TYPE)) {
      sss.unregisterSheet(registered, TYPE);
    }
    registered = uri;
    registeredCss = css;
    log("colours applied, mtime " + mtime);
  };

  const tick = () => {
    const mtime = modified();
    if (mtime === null || mtime === applied) {
      pending = 0;
    } else if (mtime !== pending) {
      pending = mtime;
    } else {
      pending = 0;
      applied = mtime;
      load(mtime);
    }
  };

  Services.obs.addObserver(function onStartup() {
    Services.obs.removeObserver(onStartup, "final-ui-startup");
    const mtime = modified();
    if (mtime !== null) {
      applied = mtime;
      load(mtime);
    }
    // Kept on globalThis so the timer is not garbage-collected.
    globalThis.ajmashellZenTimer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
    globalThis.ajmashellZenTimer.initWithCallback({ notify: tick }, POLL_MS, Ci.nsITimer.TYPE_REPEATING_SLACK);
  }, "final-ui-startup");
} catch (e) {
  Components.utils.reportError(e);
}
