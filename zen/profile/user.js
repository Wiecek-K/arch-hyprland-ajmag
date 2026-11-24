// Lets Zen load chrome/userChrome.css (matugen colours, see arch-hyprland-ajmag).
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// Transparent window (zen/README.md): Zen's own Linux switch (Zen 1.11.2b and newer) and transparent tab content.
// userChrome.css then paints the window and the sidebars with a semi-transparent Matugen surface; Hyprland blurs the desktop behind it.
user_pref("zen.widget.linux.transparency", true);
user_pref("browser.tabs.allow_transparent_browser", true);
