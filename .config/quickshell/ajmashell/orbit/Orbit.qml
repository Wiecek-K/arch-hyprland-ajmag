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
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth as BT
import qs.singletons.theme
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
            if (event.key === Qt.Key_B) {
                backdrop.variant = (backdrop.variant + 1) % backdrop.variants.length;
                event.accepted = true;
            }
        }

        OrbitBackdrop {
            id: backdrop
            anchors.fill: parent
            angle: root.angle
            coreRadius: Theme.orbit.coreSize / 2
        }

        // TEMPORARY (ticket 13): name of the background variant
        OrbitText {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Theme.orbit.padding + Theme.spacing.sm
            font.pixelSize: Theme.font.sizeSmall
            color: Theme.orbit.subtext
            text: `B: ${backdrop.name} (${backdrop.variant + 1}/${backdrop.variants.length})`
        }

        Item {
            id: field
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: tabs.top
            anchors.margins: Theme.orbit.padding

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
                        Logic.boltStrands(center, target, time, i, { coreRadius: Theme.orbit.coreSize / 2, card: item, reach: root.spread, fade: fade }).forEach((strand, layer) => {
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
                    radius: Theme.radius.sm
                    // known: filled; new: outline only (user, 2026-10-05)
                    color: node?.connected ? Theme.orbit.connected : hover.hovered ? Theme.orbit.hover : known ? Theme.orbit.node : Theme.orbit.unknown
                    border.width: chosen ? Theme.bar.ringWidth : known ? 0 : Theme.orbit.unknownBorderWidth
                    border.color: chosen ? Theme.orbit.selected : Theme.orbit.unknownBorder
                    opacity: node?.busy ? Theme.orbit.dimmed : 1

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
                anchors.centerIn: parent
                width: Theme.orbit.coreSize
                height: width
                radius: width / 2
                color: Theme.orbit.core
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
        color: active ? Theme.orbit.tab : pillHover.hovered && enabled ? Theme.orbit.hover : Theme.orbit.button
        opacity: enabled ? 1 : Theme.orbit.dimmed

        OrbitText {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, pill.width - 2 * Theme.spacing.sm)
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.font.sizeSmall
            color: pill.active ? Theme.orbit.tabText : Theme.orbit.buttonText
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

    component OrbitText: Text {
        font.family: Theme.font.family
        font.pixelSize: Theme.font.size
        font.weight: Theme.font.weight
        color: Theme.orbit.text
        elide: Text.ElideRight
    }
}
