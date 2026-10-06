// Theme — the only source of colours, fonts and spacing in Ajmashell.
// Colours come from matugen: template ~/.config/matugen/templates/ajmashell-colors.json
// writes ~/.local/state/ajmashell/colors.json; FileView watches it, so SUPER+W recolours
// the shell live, without a restart and without a matugen post_hook.
// Idea from end-4/dots-hyprland MaterialThemeLoader.qml (JSON file + FileView watchChanges):
// https://github.com/end-4/dots-hyprland/blob/239b532ec6084c3c4a0b55c4089663a25fbb2576/dots/.config/quickshell/ii/services/MaterialThemeLoader.qml
// Own implementation: JsonAdapter instead of JSON.parse + 100 ms timer, matugen names kept (snake_case).
// Override the colours file (tests): AJMASHELL_COLORS=/path/colors.json
//
// Restyling (prototype stage, 2026-10: values come from quick user tests, a styling pass comes later):
// - every look value of a component lives here, in its group (Theme.bar, Theme.notifications,
//   Theme.wallpaper, Theme.launcher …); components only read them (tools/test-theme.sh checks literals).
// - Blur is NOT here: Hyprland draws it per layer namespace (hl.layer_rule in ~/.config/hypr/configs/rules.lua:
//   ajmashell-bar, ajmashell-launcher). ignore_alpha = 0.5 there: a background with alpha below 0.5 gets
//   no blur at all. Lowering an alpha under 0.5 → lower ignore_alpha too; a new blurred window → a new rule.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Material 3 roles, matugen names: Theme.colors.primary, Theme.colors.on_surface, …
    // (camelCase is not possible: QML reads a property named onTertiaryFixed as a signal handler)
    readonly property alias colors: palette

    // The one "transparent" of the shell: helper windows that only carry rounded boxes (tooltips,
    // tray menu, notification column, wallpaper carousel), unselected states, the island ring's middle.
    // Never tint it: on the full-height notification window a colour would draw a stripe.
    // To tint the Bar, change Theme.bar.background instead.
    readonly property color transparent: "transparent"

    readonly property FontStyle font: FontStyle {}
    readonly property Spacing spacing: Spacing {}
    readonly property Radius radius: Radius {}
    readonly property Motion motion: Motion {}
    // Bar = islands on a transparent window (ADR 0002 §1); values from Waybar style/islands.css
    readonly property BarStyle bar: BarStyle {
        background: root.transparent // only the islands have a background; a light tint for the whole Bar goes here
        island: Qt.alpha(root.colors.surface_container, 0.75) // blurred by Hyprland (rules.lua layerrule-7) while alpha ≥ 0.5
        text: root.colors.secondary
        muted: root.colors.error // Waybar: #cc3436 on muted pulseaudio modules
        // BT icon while a device is connected: in the focused workspace's accent (ring dropped 2026-10-05),
        // so the connection stands out with any wallpaper (user, 2026-10-01)
        connected: root.colors.primary_fixed
        tooltip: TooltipStyle {
            background: Qt.alpha(root.colors.scrim, 0.8) // Waybar tooltip: rgba(0, 0, 0, 0.8)
            text: root.colors.inverse_surface
        }
        // tray menu, dressed like the tooltips (Waybar had GTK's own menu)
        menu: MenuStyle {
            background: Qt.alpha(root.colors.scrim, 0.85)
            text: root.colors.inverse_surface
            hover: Qt.alpha(root.colors.inverse_surface, 0.12)
            separator: Qt.alpha(root.colors.inverse_surface, 0.2)
        }
        workspace: WorkspaceStyle {
            activeBackground: Qt.alpha(root.colors.primary_fixed, 0.75)
            activeText: root.colors.background
            occupied: root.colors.secondary
            empty: root.colors.outline
            urgent: root.colors.primary
            hover: root.colors.primary
        }
    }

    // Notification popups (notifications/NotificationPopups.qml) and the bell's badge (bar/Bell.qml), ticket 10
    readonly property NotificationStyle notifications: NotificationStyle {
        background: Qt.alpha(root.colors.surface_container, 0.9) // like the wallpaper carousel's panel
        text: root.colors.on_surface
        subtext: root.colors.on_surface_variant
        critical: root.colors.error
        // like the focused workspace on the Bar (user, 2026-10-05; was error / on_error, Waybar's red dot)
        badge: root.bar.workspace.activeBackground
        badgeText: root.bar.workspace.activeText
    }

    // Wallpaper carousel (wallpaper/WallpaperPicker.qml, ticket 19)
    readonly property WallpaperStyle wallpaper: WallpaperStyle {
        backdrop: Qt.alpha(root.colors.scrim, 0.7) // user, 2026-10-01: darker (was 0.55)
        panel: Qt.alpha(root.colors.surface_container, 0.9)
        text: root.colors.on_surface
        active: root.colors.primary_fixed
        activeText: root.colors.background
        card: root.colors.surface_container_high
    }

    // Launcher (launcher/Launcher.qml, ticket 11): the colours of the rofi theme it replaces
    // (~/.config/rofi/config.rasi, matugen roles of rofi/colors.rasi)
    readonly property LauncherStyle launcher: LauncherStyle {
        background: Qt.alpha(root.colors.on_primary_fixed, 0.7) // rofi window; user, 2026-10-03: 0.7 (tried 0.8, 0.6); blur: rules.lua layerrule-6, needs alpha ≥ 0.5
        border: root.colors.secondary_container
        field: root.colors.on_primary // search field and mode buttons
        text: root.colors.on_surface
        subtext: root.colors.on_surface_variant
        modeText: root.colors.on_surface_variant // inactive mode button; user, 2026-10-03: dimmed white like "Search" (was primary_fixed)
        placeholder: root.colors.on_surface_variant // "Search" in the empty field; user, 2026-10-03: dimmed (rofi: inherit = text)
        active: root.colors.primary // selected row, current mode
        activeText: root.colors.on_secondary
        error: root.colors.error
    }

    // Orbita (orbit/Orbit.qml, ticket 12): the popup of the Bar's Wi-Fi and BT islands
    readonly property OrbitStyle orbit: OrbitStyle {
        background: Qt.alpha(root.colors.surface_container, 0.8) // user, 2026-10-03; blurred by Hyprland (blur_popups of the ajmashell-bar layer rule)
        node: root.colors.surface_container_high // known network or device (saved / paired)
        // new node, only in range (user, 2026-10-05): outline only, dimmed text, outer ring
        unknown: root.transparent
        unknownBorder: root.colors.outline_variant
        unknownText: root.colors.on_surface_variant
        hover: root.colors.surface_container_highest
        connected: root.colors.primary_fixed // like the Bar's connected BT ring
        connectedText: root.colors.on_primary_fixed
        selected: root.colors.primary
        core: root.colors.surface_container_highest
        text: root.colors.on_surface
        subtext: root.colors.on_surface_variant
        button: root.colors.secondary_container
        buttonText: root.colors.on_secondary_container
        field: root.colors.surface_container_low
        error: root.colors.error
        tab: root.colors.primary // current tab and the module switch while on
        tabText: root.colors.on_primary
        // lightning strands to the connected nodes (ticket 13), bottom to top; serpantinum: accent,
        // accent lightened 1.35×, white
        boltGlow: root.colors.primary
        boltMid: root.colors.primary_fixed
        boltCore: root.colors.on_surface
    }

    // Inline component types (not plain QtObject) so qmllint and qmlls know the members.
    component FontStyle: QtObject {
        readonly property string family: "AtkinsonHyperlegibleMono Nerd Font" // same as Waybar
        readonly property int weight: Font.Bold
        readonly property int size: 16 // px, about Waybar's 98% of the 12 pt GTK font
        readonly property int sizeSmall: 13
        readonly property int sizeLarge: 20
    }

    component Spacing: QtObject {
        readonly property int xs: 2
        readonly property int sm: 4
        readonly property int md: 8
        readonly property int lg: 12
    }

    // Short transitions only on state changes; no looping animations (CPU is the bottleneck)
    component Motion: QtObject {
        readonly property int fast: 150 // ms
        readonly property int settle: 40 // ms; wait for a burst of Hyprland events to end
        readonly property int tooltipDelay: 500 // ms; pointer rest before a Bar tooltip shows (about GTK's)
    }

    component Radius: QtObject {
        readonly property int sm: 10
        readonly property int lg: 20 // Waybar islands
    }

    component BarStyle: QtObject {
        readonly property int height: 42 // same as Waybar, so windows do not shift when swapping bars
        property color background
        readonly property int islandHeight: 38 // Waybar: 2 px above and below the modules
        readonly property int islandPadding: 15 // Waybar: horizontal padding of a module
        readonly property int islandGap: 5 // Waybar: margin between modules
        readonly property int edgePadding: 4 // Waybar: padding of .modules-left / .modules-right
        readonly property int ringWidth: 2 // state ring inside an island's edge (Island.ring; user, 2026-10-01)
        readonly property int trayIconSize: 20 // Waybar tray "icon-size"
        readonly property int traySpacing: 4 // Waybar tray "spacing"
        property color island
        property color text // default text colour in islands
        property color muted // text of a muted volume island
        property color connected
        property TooltipStyle tooltip
        property MenuStyle menu
        property WorkspaceStyle workspace
    }

    component TooltipStyle: QtObject {
        readonly property int padding: 8
        readonly property int gap: 4 // between the island and its tooltip
        property color background
        property color text
    }

    // Tray menu (bar/TrayMenu.qml, ticket 09)
    component MenuStyle: QtObject {
        readonly property int padding: 6
        readonly property int rowHeight: 30
        readonly property int rowPadding: 10
        readonly property int minWidth: 160
        readonly property int iconSize: 16
        readonly property int separatorGap: 9 // height of a separator row
        readonly property real disabledOpacity: 0.4
        property color background
        property color text
        property color hover
        property color separator
    }

    // Workspace buttons; states per ADR 0002 §7
    component WorkspaceStyle: QtObject {
        readonly property int height: 24
        readonly property int fontSize: 14 // px; a bit smaller than the clock (user, 2026-09-29: closer to Waybar)
        readonly property int padding: 4 // Waybar: button padding
        readonly property int spacing: 3 // room for the focused circle, which is wider than a button
        property color activeBackground
        property color activeText
        property color occupied
        property color empty
        property color urgent
        property color hover
    }

    component NotificationStyle: QtObject {
        readonly property int width: 350 // serpantinum popups
        readonly property int marginTop: 12 // below the Bar's exclusive zone (serpantinum)
        readonly property int marginRight: 16
        readonly property int spacing: 12 // between popups
        readonly property int padding: 12
        readonly property int iconSize: 40
        readonly property int bodyLines: 4 // longer bodies are elided
        readonly property int criticalBorder: 2
        readonly property int badgeSize: 15 // bell's badge, a circle at the top-right of the bell
        readonly property int badgeFontSize: 10
        readonly property int badgeOffsetX: -1 // badge's left edge from the bell's middle, px
        // popup animations (serpantinum): slide in from the right and fade
        readonly property int appear: 250 // ms
        readonly property int disappear: 200 // ms
        readonly property int reflow: 220 // ms; the other popups move up or down
        readonly property real slide: 0.35 // of the popup width
        property color background
        property color text
        property color subtext
        property color critical
        property color badge
        property color badgeText
    }

    component WallpaperStyle: QtObject {
        readonly property real itemWidthRatio: 0.21 // serpantinum's itemWidth 400 px on a ~1920 px wide screen
        readonly property real itemHeightRatio: 0.39 // serpantinum's itemHeight 420 px on a ~1080 px high screen
        readonly property int cardRadius: 20 // = radius.lg, like the Bar islands
        readonly property int border: 3 // ring around the current card
        readonly property int overlap: 14 // px each card tucks under its neighbour (user, 2026-10-01: no gap between cards)
        readonly property int filterDot: 18
        readonly property int filterHeight: 42
        readonly property int gap: 24 // px between the current card and the filter row / name bar (user, 2026-10-01: were too far)
        readonly property int move: 400 // ms; one slide of the carousel (serpantinum)
        readonly property int appear: 400 // ms; fade-in of the cards on open (user, 2026-10-01: 150, then 300 ms too abrupt)
        readonly property int backdropAppear: 300 // ms; the dimmed background fades in under the cards (user, 2026-10-01)
        // Curve of the slide: cubic-bezier(x1, y1, x2, y2) as in CSS, then the end point 1, 1.
        // Tune by eye, e.g. on https://cubic-bezier.com. Now: easeOutCubic (fast start, gentle stop).
        readonly property var curve: [0.33, 1, 0.68, 1, 1, 1]
        // Bucket swatches in the filter row: fixed hues naming the bucket, not theme colours (serpantinum filterData)
        readonly property var buckets: ({
                Red: "#ff4500",
                Amber: "#ffbf00", // Orange + Yellow merged (user, 2026-10-01)
                Green: "#32cd32",
                Blue: "#1e90ff",
                Purple: "#8a2be2",
                Pink: "#ff69b4",
                Monochrome: "#a9a9a9"
            })
        property color backdrop
        property color panel
        property color text
        property color active
        property color activeText
        property color card
    }

    // Sizes from ~/.config/rofi/config.rasi, so the launcher looks like rofi did
    component LauncherStyle: QtObject {
        readonly property int width: 1000
        readonly property int radius: 15
        readonly property int borderWidth: 2
        readonly property int padding: 20 // around the wallpaper pane's content and the list
        readonly property int fieldRadius: 10
        readonly property int fieldPadding: 15
        readonly property int fieldSpacing: 10 // search icon to text
        readonly property int modeSpacing: 20 // between mode buttons
        readonly property int rows: 8 // visible list rows
        readonly property int rowPadding: 8
        readonly property int rowSpacing: 10
        readonly property int iconSize: 32
        readonly property int iconGap: 26 // icon to text; rofi: spacing 15 + the icon box, measured on a screenshot
        readonly property int fontSize: 17 // px; rofi: 13 pt
        readonly property int fontWeight: Font.Medium // user, 2026-10-03: heavier than rofi's regular (font has Medium, SemiBold); the Bar is bold
        readonly property int resultSize: 34 // px; calculator result
        readonly property int calcDelay: 120 // ms; pause in typing before qalc runs (~70 ms per run)
        readonly property int calcKeyColumns: 5 // calculator keys per row (launcher.mjs CALC_KEYS: 15)
        property color background
        property color border
        property color field
        property color text
        property color subtext
        property color modeText
        property color placeholder
        property color active
        property color activeText
        property color error
    }

    // Orbita: nodes on an ellipse around the core (serpantinum NetworkPopup.qml: 720×600 window,
    // radii 260/160 + 32 px outer ring, 150×52 cards, 400 s per turn)
    component OrbitStyle: QtObject {
        readonly property int width: 900 // user, 2026-10-03: more room than serpantinum's 720 × 540
        readonly property int height: 660
        readonly property int padding: 12
        readonly property int radiusX: 270 // ellipse of the inner ring; 2 × (radiusX + ring + nodeWidth / 2) + 2 × padding ≤ width
        readonly property int radiusY: 215
        readonly property int ring: 50 // new nodes sit this much further out than known ones
        readonly property int nodeWidth: 220 // a long name wraps to a second line before it is cut
        readonly property int nodeHeight: 48
        readonly property int unknownBorderWidth: 1
        readonly property int coreSize: 260
        readonly property int buttonHeight: 28
        readonly property int tabHeight: 34
        readonly property int iconSize: 20 // node glyph, px
        readonly property int coreIconSize: 34
        readonly property real dimmed: 0.4 // busy node, disabled button
        readonly property int maxNodes: 14 // more would overlap on the orbit
        // ms per turn of the orbit. It turns every frame with sub-pixel positions: 50 ms steps rounded
        // to whole pixels looked like ~15 fps (user, 2026-10-03).
        readonly property int period: 240000
        readonly property int appear: 400 // ms; nodes fly out from the core on open (serpantinum entryAnim 600 ms)
        readonly property int reflow: 1200 // ms; nodes glide to their new places when the list changes (user, 2026-10-06: 600 too quick)
        // each node drifts ± amplitude px towards and away from the core, period ± 12% per node (user, 2026-10-06)
        readonly property var wobble: ({ amplitude: 6, period: 4000 })
        readonly property int cardsDelay: 1500 // ms; PipeWire adds a BT card a moment after the connection
        // Lightning (ticket 13, D6): wavy strands from the core to the connected nodes, a Canvas drawn
        // on the CPU every `boltTick` ms (serpantinum: 25 ms, ~40 fps) only while the Orbita is open.
        readonly property bool lightning: true
        readonly property int boltTick: 25
        readonly property int boltFade: 400 // ms; strands fade in and out with the connection (serpantinum)
        property color background
        property color node
        property color unknown
        property color unknownBorder
        property color unknownText
        property color hover
        property color connected
        property color connectedText
        property color selected
        property color core
        property color text
        property color subtext
        property color button
        property color buttonText
        property color field
        property color error
        property color tab
        property color tabText
        property color boltGlow
        property color boltMid
        property color boltCore
    }

    // Singletons load lazily and FileView reads asynchronously: read the file once, blocking,
    // so the first frame already has the wallpaper colours instead of the fallback.
    Component.onCompleted: colorsFile.text()

    FileView {
        id: colorsFile
        path: Quickshell.env("AJMASHELL_COLORS") || Quickshell.env("HOME") + "/.local/state/ajmashell/colors.json"
        blockLoading: true
        // Also catches matugen's atomic replace: FileView watches the directory, so the directory
        // must exist when the shell starts (matugen creates it on its first run).
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: error => console.warn("Theme: cannot read colours file, keeping current colours:", FileViewError.toString(error))

        // Fallback = matugen dark scheme of a neutral grey (#808080), used until the file exists.
        // qmltypes leave FileViewAdapter incomplete; JsonAdapter is one at runtime
        adapter: JsonAdapter { // qmllint disable unresolved-type
            id: palette

            property color background: "#0e1415"
            property color error: "#ffb4ab"
            property color error_container: "#93000a"
            property color inverse_on_surface: "#2b3133"
            property color inverse_primary: "#006874"
            property color inverse_surface: "#dee3e5"
            property color on_background: "#dee3e5"
            property color on_error: "#690005"
            property color on_error_container: "#ffdad6"
            property color on_primary: "#00363d"
            property color on_primary_container: "#9eeffd"
            property color on_primary_fixed: "#001f24"
            property color on_primary_fixed_variant: "#004f58"
            property color on_secondary: "#1c3438"
            property color on_secondary_container: "#cde7ec"
            property color on_secondary_fixed: "#051f23"
            property color on_secondary_fixed_variant: "#334b4f"
            property color on_surface: "#dee3e5"
            property color on_surface_variant: "#bfc8ca"
            property color on_tertiary: "#24304d"
            property color on_tertiary_container: "#dae2ff"
            property color on_tertiary_fixed: "#0e1b37"
            property color on_tertiary_fixed_variant: "#3b4664"
            property color outline: "#899294"
            property color outline_variant: "#3f484a"
            property color primary: "#82d3e0"
            property color primary_container: "#004f58"
            property color primary_fixed: "#9eeffd"
            property color primary_fixed_dim: "#82d3e0"
            property color scrim: "#000000"
            property color secondary: "#b1cbd0"
            property color secondary_container: "#334b4f"
            property color secondary_fixed: "#cde7ec"
            property color secondary_fixed_dim: "#b1cbd0"
            property color shadow: "#000000"
            property color source_color: "#808080"
            property color surface: "#0e1415"
            property color surface_bright: "#343a3b"
            property color surface_container: "#1b2122"
            property color surface_container_high: "#252b2c"
            property color surface_container_highest: "#303637"
            property color surface_container_low: "#171d1e"
            property color surface_container_lowest: "#090f10"
            property color surface_dim: "#0e1415"
            property color surface_tint: "#82d3e0"
            property color surface_variant: "#3f484a"
            property color tertiary: "#bac6ea"
            property color tertiary_container: "#3b4664"
            property color tertiary_fixed: "#dae2ff"
            property color tertiary_fixed_dim: "#bac6ea"
        }
    }
}
