// Centrum sterowania (ticket 14, D1, D4, CONTEXT.md) — the bell on the Bar opens it: a panel sliding in from the
// right edge, full height under the Bar. Top to bottom: date and the power button, look buttons (on top: user,
// 2026-10-07), Wiersze Wi-Fi / Bluetooth, sliders (speaker, microphone, eDP-1 brightness), output device and app volumes, then the Centrum powiadomień
// (ticket 16: groups per app, collapsed to the newest entry with a header to expand and clear the group; silent
// mode switch; clear all; action buttons and progress bars on the cards).
// Closes on a click beside it (HyprlandFocusGrab), on Esc and on a second click on the bell.
// Also the one place to switch the Wygląd of the Orbita and the launcher: look buttons and F2 (user, 2026-10-07).
// IPC: qs -c ajmashell ipc call control toggle
// Own implementation. Layout after caelestia's sidebar (B11 #09: full height at the right edge, slides in) and
// end-4's right sidebar (B11 #12: header with the power button, toggles and sliders above the notifications),
// ideas only; colours, buttons and lens flare (OrbitBackdrop) of our Orbita (Theme.control).
// Brightness through logind SetBrightness (B10 §2.1a): no video group needed.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth as BT
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland
import qs.notifications
import qs.orbit
import qs.singletons.barpopups
import qs.singletons.look
import qs.singletons.notifications
import qs.singletons.theme
import "control.mjs" as Logic
import "../bar/connectivity.mjs" as Net
import "../orbit/orbit.mjs" as OrbitLogic
import "../singletons/barpopups/popups.mjs" as BarLogic
import "../singletons/notifications/notifications.mjs" as NotifLogic

Scope {
    id: root

    property bool open: false
    property string screenName: ""
    property bool moving: false // following the focus to another monitor (ticket 27)
    // 0 = hidden, 1 = fully in; the window shows while above 0, so the panel can slide out before it hides
    property real shown: open ? 1 : 0
    // true for one close only: the window hides at once instead of sliding out (ticket 35)
    property bool instant: false

    // appKey → true: groups of the Centrum powiadomień shown in full (collapsed = newest entry only)
    property var expanded: ({})

    function toggleGroup(key: string): void {
        const next = Object.assign({}, expanded);
        next[key] = !next[key];
        expanded = next;
    }

    // a Wi-Fi / BT row asks for the Orbita; shell.qml passes it to the Bar of the same screen
    signal orbitRequested(string tab, string screenName)

    readonly property string backlight: "intel_backlight" // eDP-1 (B10 §2.1)

    function toggle(name: string): void {
        // a bell on another screen moves it there in one click (ticket 27, user 2026-10-10)
        if (open && (name === "" || name === screenName)) {
            open = false;
            return;
        }
        // empty name (IPC, keyboard): the monitor with the focus
        screenName = name || (Hyprland.focusedMonitor?.name ?? "");
        open = true;
    }

    // the power button asks for the Panel zasilania on the same screen; shell.qml opens it
    signal powerRequested(string screenName)

    // hide without the slide: a sliding Centrum would lie over the Panel zasilania's backdrop, both on Overlay
    // (ticket 35); shell.qml calls it on every opening of the panel, also SUPER+L over IPC
    function closeAtOnce(): void {
        instant = true;
        open = false;
        instant = false;
    }

    function openPower(): void {
        closeAtOnce(); // its focus grab would close the panel at once (as the Orbita below)
        const name = screenName;
        Qt.callLater(() => root.powerRequested(name));
    }

    function openOrbit(tab: string): void {
        open = false; // its focus grab would close the Orbita at once
        const name = screenName;
        Qt.callLater(() => root.orbitRequested(tab, name));
    }

    Behavior on shown {
        enabled: !root.instant

        NumberAnimation {
            duration: Theme.control.slide
            easing.type: Easing.OutCubic
        }
    }

    IpcHandler {
        target: "control"

        function toggle(): void {
            root.toggle("");
        }

    }

    // --- Wi-Fi and BT (as the Bar's islands) ---
    readonly property list<NetworkDevice> wifiDevices: Networking.devices.values.filter(device => device.type === DeviceType.Wifi)
    readonly property NetworkDevice wiredDevice: Networking.devices.values.find(device => device.type === DeviceType.Wired && device.connected) ?? null
    readonly property WifiNetwork network: wifiDevices.map(device => device.networks.values.find(net => net.connected)).find(net => net) ?? null
    readonly property BT.BluetoothAdapter adapter: BT.Bluetooth.defaultAdapter // qmllint disable unresolved-type
    readonly property list<BT.BluetoothDevice> btConnected: adapter?.devices.values.filter(device => device.connected) ?? [] // qmllint disable unresolved-type

    // --- brightness: sysfs to read, logind to write; one write at a time, the newest level wins ---
    property int brightness: 0
    property int maxBrightness: 0
    property int brightnessWanted: -1 // level not yet sent

    FileView {
        id: brightnessFile
        path: "/sys/class/backlight/" + root.backlight + "/brightness"
        onLoaded: root.brightness = parseInt(text()) || 0
    }

    FileView {
        id: maxBrightnessFile
        path: "/sys/class/backlight/" + root.backlight + "/max_brightness"
        onLoaded: root.maxBrightness = parseInt(text()) || 0
    }

    // sysfs sends no change events: re-read while open (keys change it too)
    Timer {
        running: root.open
        repeat: true
        triggeredOnStart: true
        interval: Theme.control.poll
        onTriggered: brightnessFile.reload()
    }

    function setBrightness(position: real): void {
        if (maxBrightness <= 0)
            return;
        brightnessWanted = Logic.brightnessRaw(position, maxBrightness);
        brightness = brightnessWanted; // the slider follows at once
        if (!brightnessProc.running)
            sendBrightness();
    }

    function sendBrightness(): void {
        if (brightnessWanted < 0)
            return;
        brightnessProc.command = Logic.brightnessCommand(backlight, brightnessWanted);
        brightnessWanted = -1;
        brightnessProc.running = true;
    }

    Process {
        id: brightnessProc
        onRunningChanged: if (!running) root.sendBrightness()
    }

    // ticket 27: closes on a press on the Bar outside every bell; moves to the focused monitor
    BarElement {
        open: root.open
        owners: BarLogic.onBell
        screenName: root.screenName
        onClose: root.open = false
        onFollow: name => {
            root.moving = true;
            root.screenName = name;
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: root.open
    }

    // Created once at startup and only hidden (as the launcher: no stall on open).
    LazyLoader {
        active: true

        // qmltypes mark PanelWindow uncreatable; Quickshell substitutes the Wayland implementation at runtime
        PanelWindow { // qmllint disable uncreatable-type
            id: win

            visible: root.shown > 0
            screen: Quickshell.screens.find(s => s.name === root.screenName) ?? null
            anchors {
                top: true
                bottom: true
                right: true
            }
            margins { // qmllint disable unqualified unresolved-type
                top: Theme.control.margin
                bottom: Theme.control.margin
                right: Theme.control.margin
            }
            implicitWidth: Theme.control.width
            color: Theme.transparent // the panel has rounded corners
            exclusionMode: ExclusionMode.Normal // under the Bar, reserves nothing itself
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "ajmashell-control"
            // OnDemand + focus grab, as the launcher: Exclusive would break the grab's click beside the panel
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            onVisibleChanged: {
                // the grab refuses a window that is not mapped yet, so arm it after the window shows
                Qt.callLater(() => grab.active = win.visible);
                if (visible) {
                    brightnessFile.reload();
                    maxBrightnessFile.reload();
                    panel.forceActiveFocus();
                }
            }

            HyprlandFocusGrab {
                id: grab
                windows: [win, ...BarPopups.bars]
                // a move to another monitor makes a new surface, which clears the grab: not a click beside it
                onCleared: {
                    if (!root.moving) {
                        root.open = false;
                        return;
                    }
                    root.moving = false;
                    Qt.callLater(() => grab.active = win.visible); // the grab again, on the new monitor's surface
                }
            }

            Rectangle {
                id: panel

                x: Math.round((1 - root.shown) * width) // slides in from the right edge
                width: parent.width
                height: parent.height
                radius: Theme.radius.lg
                color: Look.background(Theme.control)

                focus: true
                Keys.onEscapePressed: root.open = false
                // F2: next look; the only place besides the buttons below and IPC (user, 2026-10-07)
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_F2) {
                        Look.cycle();
                        event.accepted = true;
                    }
                }

                // looks with `flare` (fancy, fancy2, still; user 2026-10-07): the Orbita's lens flare behind the
                // content, as in the launcher; turns only in a look with motion
                OrbitBackdrop {
                    anchors.fill: parent
                    visible: Look.current.flare
                    open: win.visible
                }

                Column {
                    id: top

                    x: Theme.control.padding
                    y: Theme.control.padding
                    width: parent.width - 2 * Theme.control.padding
                    spacing: Theme.control.spacing

                    // header: date · power button (ADR 0002 §6: the power button lives here, not on the Bar)
                    Item {
                        width: parent.width
                        height: power.height

                        OrbitText {
                            anchors.left: parent.left
                            anchors.right: power.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatDate(clock.date, "dddd, d MMMM")
                        }

                        Pill {
                            id: power
                            anchors.right: parent.right
                            text: OrbitLogic.POWER_ICON
                            fontSize: Theme.font.sizeLarge // a lone glyph, read at a glance (user, 2026-10-07)
                            onClicked: root.openPower() // Panel zasilania (ticket 18; was wlogout)
                        }
                    }

                    // Wygląd of the Orbita and the launcher (ADR 0006): shown here, so nobody has to remember F2
                    Item {
                        width: parent.width
                        height: looks.height

                        OrbitText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Look"
                            font.pixelSize: Theme.font.sizeSmall
                            color: Theme.control.subtext
                        }

                        Row {
                            id: looks
                            anchors.right: parent.right
                            spacing: Theme.spacing.sm

                            Repeater {
                                model: Look.modes

                                Pill {
                                    required property string modelData
                                    text: modelData
                                    active: Look.mode === modelData
                                    onClicked: Look.mode = modelData
                                }
                            }
                        }
                    }

                    ConnectionRow {
                        width: parent.width
                        title: "Wi-Fi"
                        active: Networking.wifiEnabled
                        icon: Net.wifiIcon({ enabled: Networking.wifiEnabled, signal: root.network?.signalStrength ?? null, wired: root.wiredDevice !== null })
                        text: Logic.wifiRowText({ enabled: Networking.wifiEnabled, name: root.network?.name, wiredName: root.wiredDevice?.name })
                        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                        onOpened: root.openOrbit("wifi")
                    }

                    ConnectionRow {
                        width: parent.width
                        title: "Bluetooth"
                        active: root.adapter?.enabled ?? false
                        icon: Net.btIcon({ enabled: root.adapter?.enabled ?? false, connected: root.btConnected.length })
                        text: Logic.btRowText({ enabled: root.adapter?.enabled ?? false, names: root.btConnected.map(device => device.name) })
                        onToggled: {
                            if (root.adapter)
                                root.adapter.enabled = !root.adapter.enabled;
                        }
                        onOpened: root.openOrbit("bt")
                    }

                    AudioSection {
                        width: parent.width
                        showDevices: false
                        showStreams: false
                    }

                    AudioSection {
                        width: parent.width
                        microphone: true
                        showDevices: false
                        showStreams: false
                    }

                    ControlSlider {
                        width: parent.width
                        iconClickable: false
                        icon: "\u{f00df}" // brightness
                        position: root.maxBrightness > 0 ? root.brightness / root.maxBrightness : 0
                        text: Logic.brightnessPercent(root.brightness, root.maxBrightness) + "%"
                        onMoved: position => root.setBrightness(position)
                    }

                    // output device and app volumes (B10 §1.2–1.3); hidden while there is nothing to choose
                    AudioSection {
                        width: parent.width
                        showSlider: false
                        active: win.visible
                        streamsFoldable: true
                        streamsOpen: false // folded after start; stays as the user left it
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.control.separator
                    }

                    // Centrum powiadomień (ticket 16): count, silent mode (DND, as PPM on the bell), clear all
                    Item {
                        width: parent.width
                        height: clear.height

                        OrbitText {
                            anchors.left: parent.left
                            anchors.right: notifButtons.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: Notifications.count > 0 ? "Notifications (" + Notifications.count + ")" : "Notifications"
                        }

                        Row {
                            id: notifButtons
                            anchors.right: parent.right
                            spacing: Theme.spacing.sm

                            Pill {
                                text: NotifLogic.bellIcon(true) + "  Silent"
                                active: Notifications.silent
                                onClicked: Notifications.toggleSilent()
                            }

                            Pill {
                                id: clear
                                text: "Clear"
                                enabled: Notifications.count > 0
                                onClicked: Notifications.clear()
                            }
                        }
                    }
                }

                ListView {
                    id: list

                    x: Theme.control.padding
                    anchors.top: top.bottom
                    anchors.topMargin: Theme.control.spacing
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.control.padding
                    width: top.width
                    clip: true
                    model: Notifications.history

                    // a removed card slides out to the right and fades; the next card of its group moves up into its place
                    remove: Transition {
                        // above the next card of its group, which comes out from under it (ListView gives every
                        // delegate z 1)
                        PropertyAction {
                            property: "z"
                            value: 2
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                property: "opacity"
                                to: 0
                                duration: Theme.notifications.centrumDisappear
                                easing.type: Easing.InQuart // stays visible while it slides, the rest goes fast at the end (user, 2026-10-09; was InQuad)
                            }
                            NumberAnimation {
                                property: "x"
                                to: list.width * Theme.notifications.slide
                                duration: Theme.notifications.centrumDisappear
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    removeDisplaced: Transition {
                        id: reflow
                        // the next card of a collapsed group (hidden one row lower until now) does not move from
                        // there: it rises from under the removed card by itself (row.rise)
                        NumberAnimation {
                            property: "y"
                            duration: reflow.ViewTransition.item?.rising === true ? 0 : Theme.notifications.centrumReflow // qmllint disable missing-property
                            easing.type: Easing.OutCubic
                        }
                    }

                    // the history is kept as runs per app; a run is a section, but its header is drawn by the run's
                    // newest row (groupHeader), so it moves with the cards when one is removed (ticket 32)
                    section.property: "appKey"

                    delegate: Item {
                        id: row

                        required property var model
                        required property int index
                        // the newest entry of a group always shows; the rest while the group is expanded
                        readonly property bool newest: ListView.previousSection !== ListView.section
                        // removed, sliding out (index -1); when its group goes on, the next row shows the header and edges
                        readonly property bool leaving: index < 0
                        // a removed row has no model data any more: it keeps its group's key for the slide out
                        property string groupKey
                        Binding on groupKey {
                            when: !row.leaving
                            value: row.model.appKey
                            restoreMode: Binding.RestoreNone
                        }
                        readonly property bool open: root.expanded[groupKey] === true
                        readonly property bool shown: newest || open
                        readonly property int count: Notifications.groupCounts[groupKey] ?? 0
                        readonly property bool leavesGroup: leaving && count > 0
                        // ticket 32: edges of the next cards under the newest one, inside the spacing below it
                        readonly property int edgeCount: newest && !leavesGroup ? NotifLogic.stackEdges(count, open) : 0
                        // the last card shown in a group gets room for the edges, whether they show or not (no jumps)
                        readonly property bool lastShown: !open || ListView.nextSection !== ListView.section

                        // the card above it was removed: in a collapsed group it comes out from the stack (rise), in an
                        // expanded one the row takes the removed row's place at once (the header stays) and only the
                        // card slides up (slide); either way the view does not move the row (removeDisplaced)
                        readonly property bool rising: rise.running || slide.running || slidePending
                        property bool slidePending: false
                        property real slideStartY: 0 // the row's y before the removal

                        width: list.width
                        height: shown ? body.y + card.height + (lastShown ? Theme.notifications.stackSpacing : Theme.notifications.spacing) : 0
                        visible: shown

                        // the view sets the sections after creating a row: that first change is not a removal
                        property bool created: false
                        Component.onCompleted: Qt.callLater(() => row.created = true)

                        onNewestChanged: {
                            if (!created || !newest || leaving)
                                return;
                            if (!open) {
                                rise.restart();
                            } else {
                                slideStartY = y;
                                slidePending = true;
                            }
                        }

                        // the row has jumped into the removed row's place: the card starts where it was drawn before
                        onYChanged: {
                            if (!slidePending)
                                return;
                            slidePending = false;
                            slide.from = slideStartY - y - groupHeader.height;
                            slide.restart();
                        }

                        NumberAnimation {
                            id: slide
                            target: card
                            property: "y"
                            to: 0
                            duration: Theme.notifications.centrumReflow
                            easing.type: Easing.OutCubic // as removeDisplaced: the rows below move with it
                        }

                        // starts as the first edge (narrower, bottom on the edge's bottom) and grows to a full card
                        ParallelAnimation {
                            id: rise
                            NumberAnimation {
                                target: card
                                property: "y"
                                from: Theme.notifications.stackGap + Theme.notifications.stackPeek
                                to: 0
                                duration: Theme.notifications.centrumReflow
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: card
                                property: "scale"
                                from: 1 - 2 * Theme.notifications.stackInset / Math.max(card.width, 1)
                                to: 1
                                duration: Theme.notifications.centrumReflow
                                easing.type: Easing.OutCubic
                            }
                            // the edge's colour turns into the card: the card fades in over its edge-coloured copy
                            NumberAnimation {
                                target: card
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Theme.notifications.centrumReflow
                                easing.type: Easing.InOutQuad
                            }
                        }

                        // group header: app name, count, arrow (click expands), Clear (ticket 16)
                        Item {
                            id: groupHeader

                            width: parent.width
                            height: row.newest ? groupClear.height + Theme.spacing.md : 0
                            visible: row.newest && !row.leavesGroup

                            OrbitText {
                                anchors.left: parent.left
                                anchors.right: groupClear.left
                                anchors.rightMargin: Theme.spacing.md
                                anchors.verticalCenter: groupClear.verticalCenter
                                elide: Text.ElideRight
                                text: (row.count > 1 ? (row.open ? NotifLogic.GROUP_OPEN_ICON : NotifLogic.GROUP_CLOSED_ICON) + "  " : "")
                                      + row.groupKey + (row.count > 1 ? " (" + row.count + ")" : "")
                                font.pixelSize: Theme.font.sizeSmall
                                color: Theme.control.subtext
                            }

                            Pill {
                                id: groupClear
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Theme.spacing.sm
                                text: "Clear"
                                onClicked: Notifications.clearGroup(row.groupKey)
                            }

                            // Clear has its own TapHandler, but this one fires too: a tap on Clear does not expand
                            TapHandler {
                                enabled: row.count > 1
                                onTapped: eventPoint => {
                                    const p = groupHeader.mapToItem(groupClear, eventPoint.position);
                                    if (!groupClear.contains(p))
                                        root.toggleGroup(row.groupKey);
                                }
                            }
                        }

                        Item {
                            id: body

                            y: groupHeader.height
                            width: parent.width
                            height: card.height

                            // the card as an edge while it grows (row.rise); under the card, same place and size
                            Rectangle {
                                x: card.x
                                y: card.y
                                width: card.width
                                height: card.height
                                scale: card.scale
                                transformOrigin: Item.Bottom
                                radius: card.radius
                                color: Theme.notifications.stack
                                visible: row.rising
                            }

                            // each edge shows only its bottom strip: a card-sized rectangle clipped to stackPeek px
                            Repeater {
                                model: NotifLogic.STACK_MAX_EDGES

                                Item {
                                    id: edge

                                    required property int index
                                    readonly property int inset: Theme.notifications.stackInset * (index + 1)

                                    x: inset
                                    y: card.height + Theme.notifications.stackGap + (Theme.notifications.stackPeek + Theme.notifications.stackGap) * index
                                    width: body.width - 2 * inset
                                    height: Theme.notifications.stackPeek
                                    clip: true
                                    opacity: index >= row.edgeCount ? 0 : index === 0 ? 1 : Theme.notifications.stackFade

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.motion.fast
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: card.height
                                        y: parent.height - height
                                        radius: card.radius
                                        color: Theme.notifications.stack
                                    }
                                }
                            }

                            NotificationCard {
                                id: card
                                width: parent.width
                                transformOrigin: Item.Bottom // row.rise grows it from the edge
                                showAppName: false
                                time: row.model.time
                                showTime: true
                                now: clock.date.getTime()
                                appName: row.model.appName
                                summary: row.model.summary
                                body: row.model.body
                                icon: row.model.icon
                                urgency: row.model.urgency
                                progress: row.model.progress
                                actions: row.model.actions
                                closable: true
                                enabled: !row.leaving // sliding out: its model data is gone
                                onClicked: Notifications.activate(row.model.uid, "")
                                onCloseRequested: Notifications.dismiss(row.model.uid)
                                onActionInvoked: identifier => Notifications.activate(row.model.uid, identifier)
                            }
                        }
                    }

                    OrbitText {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: "No notifications"
                        font.pixelSize: Theme.font.sizeSmall
                        color: Theme.control.subtext
                    }
                }
            }
        }
    }
}
