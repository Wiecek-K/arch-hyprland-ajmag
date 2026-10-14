// Firefox skips the first line of an autoconfig file — keep this comment.
//
// Zen Browser: live matugen colours without a browser restart (Ajmashell ticket 48).
// Installed as /opt/zen-browser-bin/config.js, loaded by defaults/pref/autoconfig.js (see install.sh, section Zen).
//
// Why: Firefox reads userChrome.css (and its @import "matugen-colors.css") only at startup. This script registers the
// content of <profile>/chrome/matugen-colors.css as a user style sheet at startup and again each time matugen says
// the colours changed. The variables get !important so they win over the startup copy from userChrome.css.
// How matugen tells Zen: the script listens on the Unix socket $XDG_RUNTIME_DIR/ajmashell-zen.sock (mode 0600);
// matugen's post_hook for [templates.zen] connects to it after writing the file (socat). A connection only means
// "reload the file" — nothing is read from it. No polling: Zen does not wake up while the colours stay the same.
// When: once per Zen process, from "final-ui-startup"; the sheet service covers every window.
// Kept here, in root-owned /opt, not in a profile script: any user process can write the profile.
// Own implementation on the documented AutoConfig / nsIStyleSheetService / nsIServerSocket API (provenance:
// pochodzenie-komponentow.md in the hyprland-lua-migration project, ADR 0015).
// Roll back: sudo rm /opt/zen-browser-bin/config.js /opt/zen-browser-bin/defaults/pref/autoconfig.js, restart Zen
// (colours then change only after a restart, as before). Log: Browser Console (Ctrl+Shift+J), filter "ajmashell-zen".
try {
  const { classes: Cc, interfaces: Ci, utils: Cu } = Components;
  const sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(Ci.nsIStyleSheetService);
  const TYPE = sss.USER_SHEET;
  const SOCKET_NAME = "ajmashell-zen.sock";
  // A custom property declaration up to its ";" or "}", without one that already has !important.
  const VARIABLE = /(--[\w-]+\s*:\s*[^;!{}]*[^;!{}\s])(?=\s*[;}])/g;

  const log = msg => Services.console.logStringMessage("[ajmashell-zen] " + msg);

  let registered = null;
  let registeredCss = null;

  const colorsFile = () => {
    const f = Services.dirsvc.get("ProfD", Ci.nsIFile);
    f.append("chrome");
    f.append("matugen-colors.css");
    return f;
  };

  // Register the new sheet first and drop the old one after: no frame without the colour variables (no blink).
  // A missing, empty or broken file (no variables) keeps the sheet that works.
  const load = () => {
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
      log("skipped, no colour variables in the file");
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
    log("colours applied");
  };

  // A socket file left by a Zen that crashed blocks the bind, so it is removed first.
  const listen = () => {
    const runtime = Services.env.get("XDG_RUNTIME_DIR");
    if (!runtime) {
      log("no XDG_RUNTIME_DIR, colours change only after a restart");
      return;
    }
    const socketFile = Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
    socketFile.initWithPath(runtime + "/" + SOCKET_NAME);
    if (socketFile.exists()) {
      socketFile.remove(false);
    }
    const server = Cc["@mozilla.org/network/server-socket;1"].createInstance(Ci.nsIServerSocket);
    server.initWithFilename(socketFile, 0o600, -1);
    server.asyncListen({
      onSocketAccepted(serv, transport) {
        transport.close(0);
        load();
      },
      onStopListening() {},
    });
    // Kept on globalThis so the server is not garbage-collected.
    globalThis.ajmashellZenServer = server;
    Services.obs.addObserver(function onQuit() {
      Services.obs.removeObserver(onQuit, "quit-application");
      server.close();
      if (socketFile.exists()) {
        socketFile.remove(false);
      }
    }, "quit-application");
  };

  Services.obs.addObserver(function onStartup() {
    Services.obs.removeObserver(onStartup, "final-ui-startup");
    if (colorsFile().exists()) {
      load();
    }
    try {
      listen();
    } catch (e) {
      Cu.reportError(e);
    }
  }, "final-ui-startup");
} catch (e) {
  Components.utils.reportError(e);
}
