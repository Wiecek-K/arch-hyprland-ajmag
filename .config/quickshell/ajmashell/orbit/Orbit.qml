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
// every frame and pauses under the pointer; profile switching added (serpantinum only shows it);
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
import qs.singletons.theme
import qs.singletons.prototype
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
    // TEMPORARY (ticket 13, user 2026-10-06: "the middle element stands out too much"): core styles, C cycles
    readonly property var coreStyles: ["solid", "glass", "fade", "fade wide", "ring", "none", "glass + fade wide"]
    // TEMPORARY (ticket 13, user 2026-10-06): shape of the node cards, S cycles; island = like the Bar's islands
    readonly property var nodeShapes: ["rounded", "ellipse", "island"]
    property int nodeShape: nodeShapes.indexOf("ellipse") // starts at the user's current pick (2026-10-06)
    // TEMPORARY (ticket 13, user 2026-10-06: "take care of the buttons"): button styles, P cycles
    readonly property var pillStyles: ["filled", "glass", "outline", "soft", "text"]
    property int pillStyle: 0
    property int coreStyle: coreStyles.indexOf("glass + fade wide")
    property int backdropChoice: 0 // set to "flare, soft streak" once the backdrop exists
    // F2 / IPC "prototype": the basic look (first of each list) or the picks above (Prototype.qml)
    readonly property string coreLook: Prototype.active ? coreStyles[coreStyle] : coreStyles[0]
    readonly property string pillLook: Prototype.active ? pillStyles[pillStyle] : pillStyles[0]
    readonly property string shapeLook: Prototype.active ? nodeShapes[nodeShape] : nodeShapes[0]
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
    readonly property bool bolts: visible && Theme.orbit.lightning && Logic.hasBolts(nodes)

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

    // one step per rendered frame, so the turn is as smooth as the monitor
    FrameAnimation {
        running: root.visible && root.hoverId === "" && root.nodes.length > 0
        onTriggered: {
            root.angle = (root.angle + 2 * Math.PI * frameTime * 1000 / Theme.orbit.period) % (2 * Math.PI);
            root.clock += frameTime;
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [root]
        onCleared: root.close()
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
        enabled: root.visible
        NumberAnimation {
            duration: Theme.orbit.appear
            easing.type: Easing.OutBack
        }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Theme.radius.lg
        color: Theme.orbit.background

        focus: true
        Keys.onEscapePressed: root.close()
        Keys.onTabPressed: root.tab = root.wifiTab ? "bt" : "wifi"
        // TEMPORARY (ticket 13): B cycles the background variants to compare
        Keys.onPressed: event => {
            if (event.key === Qt.Key_F2) { // TEMPORARY (ticket 13): basic look ↔ prototype
                Prototype.toggle();
                event.accepted = true;
            } else if (event.key === Qt.Key_B) {
                root.backdropChoice = (root.backdropChoice + 1) % backdrop.variants.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_P) { // TEMPORARY (ticket 13): button styles
                root.pillStyle = (root.pillStyle + 1) % root.pillStyles.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_S) { // TEMPORARY (ticket 13): node shapes
                root.nodeShape = (root.nodeShape + 1) % root.nodeShapes.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_C) { // TEMPORARY (ticket 13): core styles
                root.coreStyle = (root.coreStyle + 1) % root.coreStyles.length;
                event.accepted = true;
            }
        }

        OrbitBackdrop {
            id: backdrop
            anchors.fill: parent
            angle: root.angle
            coreRadius: Theme.orbit.coreSize / 2
            variant: Prototype.active ? root.backdropChoice : 0
            Component.onCompleted: root.backdropChoice = variants.findIndex(v => v.name === "flare, soft streak")
        }

        // TEMPORARY (ticket 13): names of the background, core and button variants (top: the tab row is at the bottom)
        OrbitText {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Theme.orbit.padding + Theme.spacing.sm
            font.pixelSize: Theme.font.sizeSmall
            color: Theme.orbit.subtext
            text: !Prototype.active ? "F2: basic look" : `F2: prototype   B: ${backdrop.name} (${backdrop.variant + 1}/${backdrop.variants.length})   C: ${root.coreStyles[root.coreStyle]} (${root.coreStyle + 1}/${root.coreStyles.length})   P: ${root.pillStyles[root.pillStyle]} (${root.pillStyle + 1}/${root.pillStyles.length})   S: ${root.nodeShapes[root.nodeShape]} (${root.nodeShape + 1}/${root.nodeShapes.length})`
        }

        Item {
            id: field
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: tabs.top
            anchors.margins: Theme.orbit.padding

            // fade: dense under the text and buttons, gone at the edge — no visible rim;
            // fade wide: the same, spread ~1.7× the core; under the nodes and lightning so it does not dim them (user, 2026-10-06: "a larger area")
            Shape {
                id: fadeShape
                readonly property bool wide: core.style === "fade wide" || core.style === "glass + fade wide"
                anchors.centerIn: parent // the field: the core sits at its centre
                width: wide ? Theme.orbit.coreSize * 1.7 : Theme.orbit.coreSize
                height: width
                visible: root.spread > 0 && (core.style === "fade" || wide)
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillGradient: RadialGradient {
                        centerX: fadeShape.width / 2
                        centerY: fadeShape.height / 2
                        centerRadius: fadeShape.width / 2
                        focalX: centerX
                        focalY: centerY
                        GradientStop { position: 0; color: Qt.alpha(Theme.orbit.core, 0.75) }
                        GradientStop { position: fadeShape.wide ? 0.45 : 0.6; color: Qt.alpha(Theme.orbit.core, fadeShape.wide ? 0.6 : 0.55) }
                        GradientStop { position: 1; color: Theme.transparent }
                    }
                    PathRectangle {
                        width: fadeShape.width
                        height: fadeShape.height
                        radius: fadeShape.width / 2
                    }
                }
            }

            // Lightning from the core to the connected nodes, under the nodes and the core.
            // Repainted every boltTick ms only while it shows: a closed Orbita costs nothing.
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

                Timer {
                    interval: Theme.orbit.boltTick
                    running: lightning.visible
                    repeat: true
                    onTriggered: lightning.requestPaint()
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
                        Logic.boltStrands(center, target, time, i, { coreRadius: Theme.orbit.boltStart, card: item, reach: root.spread, fade: fade }).forEach((strand, layer) => {
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
                    readonly property real target: Logic.slotAngle(index, root.nodes.length)
                    property real slot // set once on creation, then follows target through the Behavior
                    property bool placed: false
                    onTargetChanged: if (placed) slot = Logic.nearestAngle(slot, target)
                    Component.onCompleted: {
                        slot = target;
                        placed = true;
                    }
                    // known nodes on the inner ring, new ones (only in range) on the outer
                    property real ringShift: known ? 0 : Theme.orbit.ring
                    // drifts slightly towards and away from the core, out of step with the others (user, 2026-10-06)
                    readonly property real drift: ringShift + Logic.wobble(modelData, root.clock, Theme.orbit.wobble)
                    readonly property var point: Logic.ellipsePoint(root.angle + slot,
                        (Theme.orbit.radiusX + drift) * root.spread, (Theme.orbit.radiusY + drift) * root.spread)

                    Behavior on slot {
                        enabled: nodeItem.placed && root.visible
                        NumberAnimation {
                            duration: Theme.orbit.reflow
                            easing.type: Easing.InOutCubic
                        }
                    }

                    Behavior on ringShift {
                        enabled: root.visible
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
                    readonly property string shape: root.shapeLook // TEMPORARY (ticket 13)
                    radius: shape === "rounded" ? Theme.radius.sm : height / 2
                    // known: filled; new: outline only (user, 2026-10-05); island: the Bar's translucent island colour
                    readonly property color fill: node?.connected ? Theme.orbit.connected : hover.hovered ? Theme.orbit.hover : known ? (shape === "island" ? Theme.bar.island : Theme.orbit.node) : Theme.orbit.unknown
                    readonly property real edge: chosen ? Theme.bar.ringWidth : known ? 0 : Theme.orbit.unknownBorderWidth
                    color: shape === "ellipse" ? Theme.transparent : fill // the ellipse is drawn by the Shape below
                    border.width: shape === "ellipse" ? 0 : edge
                    border.color: chosen ? Theme.orbit.selected : Theme.orbit.unknownBorder
                    opacity: node?.busy ? Theme.orbit.dimmed : 1

                    // TEMPORARY (ticket 13): an ellipse with soft edges (user, 2026-10-06: "not the only element with a
                    // sharp edge"): a radial gradient in a square, squashed to the card's height, so the fill and
                    // the ring fade out instead of ending in a line
                    Repeater {
                        // fill, then the ring (chosen node, or the outline of a new one)
                        model: nodeItem.shape === "ellipse" ? [
                            [[0, nodeItem.fill], [0.8, nodeItem.fill], [1, Qt.alpha(nodeItem.fill, 0)]],
                            nodeItem.edge > 0 ? [[0, Theme.transparent], [0.74, Qt.alpha(nodeItem.border.color, 0)], [0.87, nodeItem.border.color], [1, Qt.alpha(nodeItem.border.color, 0)]] : []
                        ] : []

                        Shape {
                            id: softEllipse
                            required property var modelData
                            readonly property real soft: Theme.spacing.md // how far the fade reaches past the card
                            visible: modelData.length > 0
                            x: -soft
                            y: nodeItem.height / 2 - width / 2
                            width: nodeItem.width + 2 * soft
                            height: width
                            preferredRendererType: Shape.CurveRenderer
                            transform: Scale {
                                origin.x: softEllipse.width / 2
                                origin.y: softEllipse.height / 2
                                yScale: (nodeItem.height + 2 * softEllipse.soft) / softEllipse.width
                            }
                            ShapePath {
                                strokeWidth: -1
                                fillGradient: RadialGradient {
                                    centerX: softEllipse.width / 2
                                    centerY: softEllipse.height / 2
                                    centerRadius: softEllipse.width / 2
                                    focalX: centerX
                                    focalY: centerY
                                    stops: softEllipse.modelData.map(stop => gradientStop.createObject(softEllipse, { position: stop[0], color: stop[1] }))
                                }
                                PathAngleArc {
                                    centerX: softEllipse.width / 2
                                    centerY: softEllipse.height / 2
                                    radiusX: softEllipse.width / 2
                                    radiusY: softEllipse.height / 2
                                    startAngle: 0
                                    sweepAngle: 360
                                }
                            }
                        }
                    }

                    readonly property color textColor: node?.connected ? Theme.orbit.connectedText : known ? Theme.orbit.text : Theme.orbit.unknownText

                    Behavior on color {
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
                        onTapped: root.select(nodeItem.modelData)
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
                readonly property string style: root.coreLook
                color: style === "solid" ? Theme.orbit.core : style === "glass" || style === "glass + fade wide" ? Qt.alpha(Theme.orbit.core, 0.45) : Theme.transparent
                border.width: style === "ring" ? 1 : 0
                border.color: Theme.orbit.unknownBorder
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

                    Grid {
                        anchors.horizontalCenter: parent.horizontalCenter
                        columns: Math.min(2, root.actions.length)
                        spacing: Theme.spacing.sm

                        Repeater {
                            model: root.actions

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

    // Rounded button: tabs, the module switch, the core's actions.
    component Pill: Rectangle {
        id: pill

        property string text
        property bool active: false
        signal clicked

        implicitWidth: Math.ceil(label.implicitWidth) + 2 * Theme.spacing.lg
        height: Theme.orbit.tabHeight
        radius: height / 2
        readonly property string style: root.pillLook
        readonly property bool hot: pillHover.hovered && enabled
        // TEMPORARY (ticket 13): filled / glass / outline / soft / text, see pillStyles
        color: {
            switch (style) {
            case "glass":
                return Qt.alpha(active ? Theme.orbit.tab : Theme.orbit.button, active ? 0.45 : hot ? 0.5 : 0.3);
            case "outline":
                return hot ? Qt.alpha(Theme.orbit.text, 0.08) : Theme.transparent;
            case "soft":
                return active ? Qt.alpha(Theme.orbit.tab, 0.25) : Qt.alpha(Theme.orbit.text, hot ? 0.14 : 0.07);
            case "text":
                return hot ? Qt.alpha(Theme.orbit.text, 0.06) : Theme.transparent;
            default:
                return active ? Theme.orbit.tab : hot ? Theme.orbit.hover : Theme.orbit.button;
            }
        }
        border.width: style === "glass" || style === "outline" ? 1 : 0
        border.color: active ? Theme.orbit.selected : style === "glass" ? Qt.alpha(Theme.orbit.text, 0.15) : Theme.orbit.unknownBorder
        opacity: enabled ? 1 : Theme.orbit.dimmed

        OrbitText {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, pill.width - 2 * Theme.spacing.sm)
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.font.sizeSmall
            color: pill.style === "filled" ? (pill.active ? Theme.orbit.tabText : Theme.orbit.buttonText) : pill.active ? Theme.orbit.selected : Theme.orbit.text
            font.weight: pill.active && pill.style === "text" ? Font.Bold : Theme.font.weight
            text: pill.text
        }

        HoverHandler {
            id: pillHover
        }

        TapHandler {
            enabled: pill.enabled
            onTapped: pill.clicked()
        }
    }

    Component {
        id: gradientStop // TEMPORARY (ticket 13): stops of the soft ellipse
        GradientStop {}
    }

    component OrbitText: Text {
        font.family: Theme.font.family
        font.pixelSize: Theme.font.size
        font.weight: Theme.font.weight
        color: Theme.orbit.text
        elide: Text.ElideRight
    }
}
