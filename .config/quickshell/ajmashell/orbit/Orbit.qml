// Orbita — popup of the Bar's Wi-Fi and BT islands (CONTEXT.md, B11 #02, D3): known and visible
// networks or devices float on an orbit around a core; the core shows the chosen node and its actions.
// Wi-Fi: scan, signal, connect to a known or new network (password typed here), disconnect, forget.
// BT: scan, pairing (a code to confirm shown in the core, bt-pair.py), connect, disconnect, battery, trusted, forget, headset profile A2DP ↔ HFP.
// Adapted from serpantinum src/quickshell/network/NetworkPopup.qml (orbit of nodes around a core,
// one popup with Wi-Fi / BT tabs, scanning only while open, password in the core, pair → trust → connect):
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// Copyright (C) 2026 Illia Miroshnichenko — AGPL-3.0-or-later
// Lightning (ticket 13) from the same file, nodeLinesCanvas: three wavy strands per node on a Canvas
// repainted every 25 ms, only while open.
// Changes: written anew in ~400 lines instead of 2800 — no Ethernet tab,
// intro choreography, sounds, multi-core layout, list caching; state through bindings (no Connections
// per device), logic in orbit.mjs; a click selects a node and the core offers its actions (serpantinum
// connects on click, disconnects by holding the core); our Theme instead of its palette; the orbit turns
// and the lightning flickers on one clock (Theme.orbit.fps, not every 25 ms), the orbit pauses under
// the pointer, in a look without motion (Theme.orbit.looks) it stands
// still with the connected nodes on top; profile switching added (serpantinum only shows it);
// lightning to the connected nodes (serpantinum: to the info nodes of a connection), geometry in
// orbit.mjs, colours from Theme.orbit, can be switched off (Theme.orbit.lightning).
// Closes on a click outside (HyprlandFocusGrab), on Esc and on a second click on the same island.
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth as BT
import qs.singletons.barpopups
import qs.singletons.theme
import qs.singletons.look
import "orbit.mjs" as Logic
import "../bar/connectivity.mjs" as Net

PopupWindow {
    id: root

    property Item source: null // island the Orbita hangs under
    property string tab: "wifi" // "wifi" | "bt"
    readonly property bool wifiTab: tab === "wifi"

    function toggle(item: Item, name: string): void {
        if (visible && source === item && tab === name) {
            close();
            return;
        }
        source = item;
        tab = name;
        visible = true;
    }

    function close(): void {
        visible = false;
    }

    // --- state ---------------------------------------------------------------------------

    property string selectedId: "" // empty = the connected node
    property string passwordFor: "" // network waiting for a typed password
    property var failure: null // { id, text } of the last failed Wi-Fi connection
    property string hoverId: "" // node under the pointer; the orbit stops while set
    property real angle: 0 // turn of the whole orbit
    property real clock: 0 // s; drives each node's wobble, stops with the orbit
    // Look buttons and F2 in the Centrum sterowania, IPC "look": basic, fancy, fancy2 or still, their picks in Theme.orbit.looks (Look.qml)
    readonly property var look: Look.current
    // the open Orbita in a look with motion: the orbit turns, nodes wobble and glide, colours fade
    readonly property bool animate: visible && look.motion
    // without motion the orbit stands still at its start, connected nodes on top
    readonly property real turn: look.motion ? angle : 0
    property real spread: 0 // 0 → 1 on open: nodes fly out from the core
    property var cards: ({}) // Logic.parseCards() of `pactl -f json list cards`
    property var watched: null // Wi-Fi network being connected, for its connectionFailed
    property var pairing: null // BT device being paired, connected once paired
    property string pairNext: "" // address to pair once the helper of a cancelled pairing has exited
    property bool pairAnswered: false // the helper reported "done" or "failed"
    property var prompt: null // { id, event, code } while the device being paired asks (Logic.pairEvent)

    readonly property var wifiDevice: Networking.devices.values.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property BT.BluetoothAdapter adapter: BT.Bluetooth.defaultAdapter // qmllint disable unresolved-type
    readonly property bool moduleOn: wifiTab ? Networking.wifiEnabled : (adapter?.enabled ?? false)
    // read only while open, so a closed Orbita costs nothing when signals or devices change
    readonly property var networks: visible && wifiDevice ? wifiDevice.networks.values : []
    readonly property var devices: visible && adapter ? adapter.devices.values : [] // qmllint disable unresolved-type

    readonly property var nodes: {
        if (!visible || !moduleOn)
            return [];
        if (wifiTab)
            return Logic.wifiNodes(networks.map(net => ({
                name: net.name,
                signal: net.signalStrength,
                known: net.known,
                connected: net.connected,
                security: net.security,
                busy: net.stateChanging
            })), Theme.orbit.maxNodes);
        return Logic.btNodes(devices.map(dev => ({
            address: dev.address,
            name: dev.name,
            deviceName: dev.deviceName,
            icon: dev.icon,
            connected: dev.connected,
            paired: dev.paired,
            trusted: dev.trusted,
            batteryAvailable: dev.batteryAvailable,
            battery: dev.battery,
            busy: dev.pairing || dev.state === BT.BluetoothDeviceState.Connecting || dev.state === BT.BluetoothDeviceState.Disconnecting
        })), Theme.orbit.maxNodes);
    }
    readonly property var selected: nodes.find(node => node.id === selectedId) ?? nodes.find(node => node.connected) ?? null
    readonly property var profile: !wifiTab && selected ? root.cards[selected.id.toLowerCase()] ?? null : null
    readonly property bool passwordMode: wifiTab && selected !== null && selected.id === passwordFor
    readonly property bool promptMode: !wifiTab && selected !== null && selected.id === prompt?.id
    readonly property var actions: {
        if (!selected)
            return [];
        if (passwordMode)
            return ["submit", "cancel"];
        if (promptMode)
            return Logic.pairActions(prompt);
        return wifiTab ? Logic.wifiActions(selected) : Logic.btActions(selected, profile);
    }
    readonly property int btConnected: devices.filter(dev => dev.connected).length
    // only in a look with motion: still strands looked poor (user, 2026-10-06)
    readonly property bool bolts: animate && Theme.orbit.lightning && Logic.hasBolts(nodes)
    readonly property int connectedCount: nodes.filter(node => node.connected).length

    function network(id: string): var {
        return wifiDevice?.networks.values.find(net => net.name === id) ?? null;
    }

    function device(id: string): var {
        return adapter?.devices.values.find(dev => dev.address === id) ?? null; // qmllint disable unresolved-type
    }

    function select(id: string): void {
        selectedId = id;
        passwordFor = "";
        failure = null;
    }

    // Double click on a node (ticket 26): the first click selected it, the second runs its first
    // button, through run() like a click on that button.
    function runDefault(id: string): void {
        select(id);
        const action = Logic.doubleClickAction(actions, selected?.busy ?? false);
        if (action && selected?.id === id)
            run(action);
    }

    function run(action: string): void {
        const id = selected?.id ?? "";
        failure = null;
        if (action === "confirm" || action === "deny") {
            pairProc.write(action === "confirm" ? "yes\n" : "no\n");
            prompt = null;
        } else if (action === "cancel") {
            passwordFor = "";
        } else if (action === "submit") {
            const net = network(id);
            if (net && passwordField.text !== "") {
                watched = net;
                net.connectWithPsk(passwordField.text);
            }
            passwordFor = "";
        } else if (action === "program") {
            Quickshell.execDetached(["nm-connection-editor"]);
            close();
        } else if (action === "password") {
            passwordFor = id;
        } else if (wifiTab) {
            const net = network(id);
            if (!net)
                return;
            if (action === "connect") {
                watched = net;
                net.connect();
            } else if (action === "disconnect") {
                net.disconnect();
            } else if (action === "forget") {
                net.forget();
            }
        } else {
            const dev = device(id);
            if (!dev)
                return;
            if (action === "connect")
                dev.connect();
            else if (action === "disconnect")
                dev.disconnect();
            else if (action === "pair") {
                // the helper calls Pair() and is its agent, so a code to confirm comes back here
                pairing = dev;
                prompt = null;
                if (pairProc.running) { // a pairing is still running: cancel it, start this one when it exits
                    pairNext = id;
                    pairProc.running = false;
                } else {
                    startPair(id);
                }
            } else if (action === "trust" || action === "untrust")
                dev.trusted = action === "trust";
            else if (action === "forget")
                dev.forget();
            else if (action === "profile" && profile?.other) {
                profileProc.command = ["pactl", "set-card-profile", profile.card, profile.other];
                profileProc.running = true;
            }
        }
    }

    function refreshCards(): void {
        if (visible && !wifiTab)
            cardsProc.running = true;
    }

    function reset(): void {
        selectedId = "";
        passwordFor = "";
        failure = null;
        hoverId = "";
    }

    onTabChanged: {
        reset();
        refreshCards();
    }
    onBtConnectedChanged: cardsTimer.restart()

    // The grab refuses a window that is not mapped yet, so arm it after the popup shows.
    onVisibleChanged: {
        reset();
        if (visible) {
            refreshCards();
            Qt.callLater(() => {
                grab.active = visible;
                spread = visible ? 1 : 0;
                panel.forceActiveFocus();
            });
        } else {
            grab.active = false;
            spread = 0;
            watched = null;
            pairing = null;
            pairNext = "";
            prompt = null;
            pairProc.running = false; // SIGTERM: the helper cancels the pairing
        }
    }

    function startPair(id: string): void {
        pairAnswered = false;
        pairProc.command = [Quickshell.shellPath("orbit/bt-pair.py"), id];
        pairProc.running = true;
    }

    // one stdout line of bt-pair.py
    function handlePairOutput(line: string): void {
        const event = Logic.pairEvent(line);
        const id = pairProc.command[1] ?? "";
        if (!event || pairNext !== "") // a cancelled helper still talking
            return;
        if (event.event === "done" || event.event === "failed")
            pairAnswered = true;
        if (event.event === "confirm" || event.event === "display") {
            prompt = { id: id, event: event.event, code: event.code };
            selectedId = id;
        } else {
            prompt = null;
            if (event.event === "failed") {
                pairing = null;
                failure = { id: id, text: event.text };
            }
        }
    }

    onPasswordModeChanged: {
        passwordField.text = "";
        if (passwordMode)
            Qt.callLater(() => passwordField.forceActiveFocus());
        else
            panel.forceActiveFocus();
    }

    // scan only while the Orbita is open on that tab (serpantinum); Binding restores the old value after
    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: true
        when: root.visible && root.wifiTab && root.wifiDevice !== null
    }

    Binding {
        target: root.adapter
        property: "discovering"
        value: true
        when: root.visible && !root.wifiTab && (root.adapter?.enabled ?? false)
    }

    Connections {
        target: root.watched
        ignoreUnknownSignals: true

        function onConnectionFailed(reason: int): void {
            const result = Logic.wifiFailure(reason);
            root.failure = { id: root.watched.name, text: result.text };
            if (result.askPassword)
                root.passwordFor = root.watched.name;
            root.watched = null;
        }

        function onConnectedChanged(): void {
            if (root.watched?.connected)
                root.watched = null;
        }
    }

    // pair → trust → connect, like serpantinum and blueman: a paired device may reconnect by itself
    Connections {
        target: root.pairing
        ignoreUnknownSignals: true

        function onPairedChanged(): void {
            const dev = root.pairing;
            if (!dev?.paired)
                return;
            root.pairing = null;
            dev.trusted = true;
            if (!dev.connected) // headphones often connect by themselves right after pairing
                dev.connect();
        }
    }

    Process {
        id: cardsProc
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: root.cards = Logic.parseCards(text)
        }
    }

    Process {
        id: pairProc
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => root.handlePairOutput(data)
        }
        onRunningChanged: {
            if (running)
                return;
            const id = command[1] ?? "";
            if (root.pairNext !== "") {
                const next = root.pairNext;
                root.pairNext = "";
                root.startPair(next);
            } else if (!root.pairAnswered && root.pairing) { // the helper died without an answer (e.g. a D-Bus error)
                root.pairing = null;
                root.prompt = null;
                root.failure = { id: id, text: Logic.PAIR_FAILED };
            }
        }
    }

    Process {
        id: profileProc
        onRunningChanged: {
            if (!running)
                root.refreshCards();
        }
    }

    Timer {
        id: cardsTimer
        interval: Theme.orbit.cardsDelay
        onTriggered: root.refreshCards()
    }

    // One clock for all motion, Look's (ticket 28; Theme.orbit.fps steps a second): the turn, the lightning
    // and the flare in the same step, so the shell draws one frame per tick (two separate clocks drew up to
    // both rates together). The orbit pauses under the pointer, the lightning keeps flickering. The nodes
    // keep their own angle, which pauses (user, 2026-10-09); the flare takes the shell's shared one.
    ClockUser {
        id: motion
        active: root.animate && root.nodes.length > 0
    }

    Connections {
        target: Look
        enabled: motion.active

        function onTick(): void {
            if (root.hoverId === "") {
                root.angle = (root.angle + 2 * Math.PI * Look.tickMs / Theme.orbit.period) % (2 * Math.PI);
                root.clock += Look.tickMs / 1000;
            }
            if (lightning.visible)
                lightning.requestPaint();
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [root, ...BarPopups.bars]
        onCleared: root.close()
    }

    // ticket 27: a press elsewhere on the Bar closes it; the grab lets Bar clicks through, so that island opens its own
    Connections {
        target: BarPopups

        function onPressed(hit: var): void {
            if (root.visible && BarPopups.closes(hit, root.source))
                root.close();
        }
    }

    visible: false
    anchor.item: source
    // Centred under the island, but shifted to stay on screen: Hyprland does not slide an xdg popup
    // that sticks out, it put the Orbita of the right-hand Wi-Fi island at the left edge.
    anchor.rect.x: {
        if (!source)
            return 0;
        const center = source.mapToItem(null, source.width / 2, 0).x;
        const half = Theme.orbit.width / 2 + Theme.orbit.padding;
        return Math.max(half, Math.min(source.Window.width - half, center)) - center;
    }
    anchor.rect.y: 0
    anchor.rect.width: source?.width ?? 0
    anchor.rect.height: (source?.height ?? 0) + Theme.bar.tooltip.gap
    // qmltypes give these as Edges::Flags, which qmllint cannot resolve
    anchor.edges: Edges.Bottom // qmllint disable missing-type
    anchor.gravity: Edges.Bottom // qmllint disable missing-type

    implicitWidth: Theme.orbit.width
    implicitHeight: Theme.orbit.height
    color: Theme.transparent // only the rounded box below is drawn

    Behavior on spread {
        enabled: root.animate
        NumberAnimation {
            duration: Theme.orbit.appear
            easing.type: Easing.OutBack
        }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Theme.radius.lg
        color: Look.background(Theme.orbit)

        focus: true
        Keys.onEscapePressed: root.close()
        Keys.onTabPressed: root.tab = root.wifiTab ? "bt" : "wifi"

        OrbitBackdrop {
            anchors.fill: parent
            visible: root.look.flare
            open: root.visible
        }

        Item {
            id: field
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: tabs.top
            anchors.margins: Theme.orbit.padding

            // glass look: a fade under the core, dense under the text and buttons, gone at the edge (no
            // visible rim), spread wider than the core; under the nodes and lightning so it does not dim them
            Shape {
                id: fadeShape
                anchors.centerIn: parent // the field: the core sits at its centre
                width: Theme.orbit.coreSize * Theme.orbit.fadeScale
                height: width
                visible: root.spread > 0 && root.look.glass
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillGradient: RadialGradient {
                        centerX: fadeShape.width / 2
                        centerY: fadeShape.height / 2
                        centerRadius: fadeShape.width / 2
                        focalX: centerX
                        focalY: centerY
                        GradientStop { position: Theme.orbit.fadeStops[0][0]; color: Qt.alpha(Theme.orbit.core, Theme.orbit.fadeStops[0][1]) }
                        GradientStop { position: Theme.orbit.fadeStops[1][0]; color: Qt.alpha(Theme.orbit.core, Theme.orbit.fadeStops[1][1]) }
                        GradientStop { position: Theme.orbit.fadeStops[2][0]; color: Qt.alpha(Theme.orbit.core, Theme.orbit.fadeStops[2][1]) }
                    }
                    PathRectangle {
                        width: fadeShape.width
                        height: fadeShape.height
                        radius: fadeShape.width / 2
                    }
                }
            }

            // Lightning from the core to the connected nodes, under the nodes and the core.
            // Repainted on each step of the motion clock only while it shows: a closed Orbita costs nothing.
            Canvas {
                id: lightning
                anchors.fill: parent
                property real fade: root.bolts ? 1 : 0
                visible: fade > 0

                Behavior on fade {
                    enabled: root.visible
                    NumberAnimation {
                        duration: Theme.orbit.boltFade
                    }
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const center = { x: width / 2, y: height / 2 };
                    const time = Date.now() / 1000;
                    const colors = [Theme.orbit.boltGlow, Theme.orbit.boltMid, Theme.orbit.boltCore]; // strand order of boltStrands
                    ctx.lineJoin = "round";
                    ctx.lineCap = "round";
                    for (let i = 0; i < nodeRepeater.count; i++) {
                        const item = nodeRepeater.itemAt(i); // delegates in the order of root.nodes
                        if (!item || !Logic.getsBolt(root.nodes[i]))
                            continue;
                        const target = { x: item.x + item.width / 2, y: item.y + item.height / 2 };
                        Logic.boltStrands(center, target, time, i, { start: Theme.orbit.boltStart, card: item, reach: root.spread, fade: fade }).forEach((strand, layer) => {
                            ctx.beginPath();
                            ctx.moveTo(strand.points[0].x, strand.points[0].y);
                            for (const point of strand.points.slice(1))
                                ctx.lineTo(point.x, point.y);
                            ctx.lineWidth = strand.width;
                            ctx.strokeStyle = colors[layer];
                            ctx.globalAlpha = strand.alpha;
                            ctx.stroke();
                        });
                    }
                }
            }

            Repeater {
                id: nodeRepeater
                // ids only: the delegates stay when a node's signal or battery changes
                model: ScriptModel {
                    values: root.nodes.map(node => node.id)
                }

                // One network or device. Size never depends on state (no jumps): state is colour only.
                Rectangle {
                    id: nodeItem

                    required property string modelData
                    required property int index
                    readonly property var node: root.nodes.find(node => node.id === modelData) ?? null
                    readonly property bool chosen: root.selected?.id === modelData
                    readonly property bool known: node?.known ?? true
                    // When the list changes the node glides to its new place, the short way round,
                    // and between the rings (user, 2026-10-06: nodes jumped when a network went away).
                    readonly property real target: Logic.slotAngle(index, root.nodes.length, root.connectedCount)
                    property real slot // set once on creation, then follows target through the Behavior
                    property bool placed: false
                    onTargetChanged: if (placed) slot = Logic.nearestAngle(slot, target)
                    Component.onCompleted: {
                        slot = target;
                        placed = true;
                    }
                    // known nodes on the inner ring, new ones (only in range) on the outer
                    property real ringShift: known ? 0 : Theme.orbit.ring
                    // drifts slightly towards and away from the core, in step or not as Theme.orbit.wobble says (user, 2026-10-06)
                    readonly property real drift: ringShift + (root.look.motion ? Logic.wobble(modelData, root.clock, Theme.orbit.wobble) : 0)
                    readonly property var point: Logic.ellipsePoint(root.turn + slot,
                        (Theme.orbit.radiusX + drift) * root.spread, (Theme.orbit.radiusY + drift) * root.spread)

                    Behavior on slot {
                        enabled: nodeItem.placed && root.animate
                        NumberAnimation {
                            duration: Theme.orbit.reflow
                            easing.type: Easing.InOutCubic
                        }
                    }

                    Behavior on ringShift {
                        enabled: root.animate
                        NumberAnimation {
                            duration: Theme.orbit.reflow
                            easing.type: Easing.InOutCubic
                        }
                    }

                    // not rounded: at ~7 px/s whole-pixel steps show as stutter
                    x: field.width / 2 + point.x - width / 2
                    y: field.height / 2 + point.y - height / 2
                    width: Theme.orbit.nodeWidth
                    height: Theme.orbit.nodeHeight
                    radius: Theme.radius.sm
                    // known: filled; new: outline only (user, 2026-10-05)
                    color: node?.connected ? Theme.orbit.connected : hover.hovered ? Theme.orbit.hover : known ? Theme.orbit.node : Theme.orbit.unknown
                    border.width: chosen ? Theme.bar.ringWidth : known ? 0 : Theme.orbit.unknownBorderWidth
                    border.color: chosen ? Theme.orbit.selected : Theme.orbit.unknownBorder
                    opacity: node?.busy ? Theme.orbit.dimmed : 1

                    readonly property color textColor: node?.connected ? Theme.orbit.connectedText : known ? Theme.orbit.text : Theme.orbit.unknownText

                    Behavior on color {
                        enabled: root.look.motion
                        ColorAnimation {
                            duration: Theme.motion.fast
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing.md
                        anchors.rightMargin: Theme.spacing.md
                        spacing: Theme.spacing.md

                        OrbitText {
                            id: glyph
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.orbit.iconSize
                            color: nodeItem.textColor
                            text: nodeItem.node?.glyph ?? ""
                        }

                        OrbitText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - glyph.width - info.width - 2 * parent.spacing
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere // a long name takes two lines before it is cut
                            maximumLineCount: 2
                            font.pixelSize: Theme.font.sizeSmall // longer names fit
                            color: nodeItem.textColor
                            text: nodeItem.node?.name ?? ""
                        }

                        OrbitText {
                            id: info
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.font.sizeSmall
                            color: nodeItem.textColor
                            text: {
                                const node = nodeItem.node;
                                if (!node)
                                    return "";
                                if (root.wifiTab)
                                    return `${node.signal}%`;
                                return node.battery !== null ? `${node.battery}%` : "";
                            }
                        }
                    }

                    HoverHandler {
                        id: hover
                        onHoveredChanged: {
                            if (hovered)
                                root.hoverId = nodeItem.modelData;
                            else if (root.hoverId === nodeItem.modelData)
                                root.hoverId = "";
                        }
                    }

                    TapHandler {
                        // one click selects, a double click also runs the node's main action (ticket 26);
                        // a third click is ignored, so it does not close the password field the second one opened
                        onTapped: {
                            if (tapCount === 1)
                                root.select(nodeItem.modelData);
                            else if (tapCount === 2)
                                root.runDefault(nodeItem.modelData);
                        }
                    }
                }
            }

            // The chosen node with its state and actions; a password field for a new secured network.
            Rectangle {
                id: core
                anchors.centerIn: parent
                width: Theme.orbit.coreSize
                height: width
                radius: width / 2
                color: root.look.glass ? Qt.alpha(Theme.orbit.core, Theme.orbit.glassAlpha) : Theme.orbit.core
                opacity: root.spread > 0 ? 1 : 0

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 2 * Theme.orbit.padding - 2 * Theme.spacing.lg
                    spacing: Theme.spacing.sm

                    OrbitText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Theme.orbit.coreIconSize
                        text: {
                            const node = root.selected;
                            if (node)
                                return node.glyph ?? "";
                            return root.wifiTab ? Net.wifiIcon({ enabled: root.moduleOn }) : Net.btIcon({ enabled: root.moduleOn, connected: 0 });
                        }
                    }

                    OrbitText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.selected?.name ?? Logic.emptyLine(root.tab, root.moduleOn)
                    }

                    OrbitText {
                        visible: root.selected !== null
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Theme.font.sizeSmall
                        color: root.failure?.id === root.selected?.id ? Theme.orbit.error : Theme.orbit.subtext
                        text: {
                            if (!root.selected)
                                return "";
                            if (root.failure?.id === root.selected.id)
                                return root.failure.text;
                            if (root.promptMode)
                                return Logic.pairPromptText(root.prompt);
                            return Logic.statusLine(root.tab, root.selected, root.profile);
                        }
                    }

                    // the pairing code, to compare with the device or type on it
                    OrbitText {
                        visible: root.promptMode
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Theme.font.sizeLarge
                        font.letterSpacing: Theme.spacing.xs
                        text: root.prompt?.code ?? ""
                    }

                    Rectangle {
                        visible: root.passwordMode
                        width: parent.width
                        height: Theme.orbit.buttonHeight
                        radius: Theme.radius.sm
                        color: Theme.orbit.field

                        TextInput {
                            id: passwordField
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacing.md
                            anchors.rightMargin: Theme.spacing.md
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            echoMode: TextInput.Password
                            font.family: Theme.font.family
                            font.pixelSize: Theme.font.sizeSmall
                            color: Theme.orbit.text
                            selectionColor: Theme.orbit.selected
                            onAccepted: root.run("submit")
                            Keys.onEscapePressed: root.run("cancel")
                        }

                        OrbitText {
                            visible: passwordField.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.spacing.md
                            font.pixelSize: Theme.font.sizeSmall
                            color: Theme.orbit.subtext
                            text: "Password"
                        }
                    }

                    // rows of two, each centred: a lone third button sits in the middle (user, 2026-10-06)
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacing.sm

                        Repeater {
                            model: Logic.actionRows(root.actions)

                            Row {
                                id: actionRow
                                required property var modelData
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Theme.spacing.sm

                                Repeater {
                                    model: actionRow.modelData

                                    Pill {
                                        required property string modelData
                                        width: Theme.orbit.coreSize / 2 - Theme.orbit.padding - Theme.spacing.lg
                                        text: Logic.actionLabel(modelData, root.profile)
                                        enabled: root.promptMode || !(root.selected?.busy ?? false) // pairing is busy, yet asks
                                        onClicked: root.run(modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Row {
            id: tabs
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: Theme.orbit.padding
            spacing: Theme.spacing.md

            Pill {
                text: "Wi-Fi"
                active: root.wifiTab
                onClicked: root.tab = "wifi"
            }

            Pill {
                text: "Bluetooth"
                active: !root.wifiTab
                onClicked: root.tab = "bt"
            }

            Pill {
                text: Logic.POWER_ICON
                active: root.moduleOn
                onClicked: {
                    if (root.wifiTab)
                        Networking.wifiEnabled = !Networking.wifiEnabled;
                    else if (root.adapter)
                        root.adapter.enabled = !root.adapter.enabled;
                }
            }
        }
    }
}
