// Pure logic of the Orbita (ticket 12): Wi-Fi networks and BT devices as orbit nodes, the actions
// each node offers, the A2DP ↔ HFP headset profile, node positions on the orbit and the "lightning"
// strands from the core to the connected nodes (ticket 13).
// A JS module (not QML) so tools/test-orbit.mjs can test it with node.
// Adapted from serpantinum src/quickshell/network/NetworkPopup.qml (rebuildWifiData, rebuildBtData,
// orbit node placement, nodeLinesCanvas.onPaint) and network/bluetooth_panel_logic.sh (profile of a BlueZ card):
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// Copyright (C) 2026 Illia Miroshnichenko — AGPL-3.0-or-later
// Changes: security from Quickshell's enum (serpantinum compares raw numbers that do not match it);
// profile switching (serpantinum only shows the profile) from `pactl -f json` instead of awk + jq;
// one shared orbit for every node (no per-device cores); sorting by state, not alphabetically;
// lightning geometry returned as point lists (Orbit.qml strokes them), strands to the connected
// nodes instead of to the info nodes of a connection.
// SPDX-License-Identifier: AGPL-3.0-or-later

import { wifiIcon } from "../bar/connectivity.mjs";

// Quickshell.Networking enums in their declared order (tools/test-orbit.mjs checks it against the qmltypes)
export const SECURITY = ["Wpa3SuiteB192", "Sae", "Wpa2Eap", "Wpa2Psk", "WpaEap", "WpaPsk", "StaticWep",
    "DynamicWep", "Leap", "Owe", "Open", "Unknown"];
export const FAIL_REASONS = ["Unknown", "NoSecrets", "WifiClientDisconnected", "WifiClientFailed",
    "WifiAuthTimeout", "WifiNetworkLost"];

export const BT_GLYPHS = {
    headphones: "\u{f02cb}",
    speaker: "\u{f04c3}",
    phone: "\u{f011c}",
    mouse: "\u{f037d}",
    keyboard: "\u{f030c}",
    gamepad: "\u{f0297}",
    computer: "\u{f0322}",
    device: "\u{f00af}", // the BT rune, as on the Bar's island
};

// Button text of each action; "profile" is named by the profile it switches to (profileLabel).
export const ACTION_LABELS = {
    connect: "Connect",
    disconnect: "Disconnect",
    forget: "Forget",
    password: "Connect",
    program: "Open settings",
    pair: "Pair",
    trust: "Trust",
    untrust: "Untrust",
    submit: "Connect", // the typed password
    cancel: "Cancel",
    confirm: "Confirm", // the pairing code matches
    deny: "Deny",
};

export const POWER_ICON = "\u{f0425}"; // module switch in the tab row

function percent(value) {
    return Math.round((value ?? 0) * 100);
}

// --- Wi-Fi ---------------------------------------------------------------------------------

// "open" connects at once, "psk" needs a password typed in the Orbita, "program" needs
// nm-connection-editor (enterprise, WEP, LEAP: D3 leaves them to the program).
export function securityKind(security) {
    const name = SECURITY[security];
    if (name === "Open" || name === "Owe")
        return "open";
    if (name === "Sae" || name === "Wpa2Psk" || name === "WpaPsk")
        return "psk";
    return "program";
}

// networks: [{ name, signal (0–1), known, connected, security (enum value) }].
// Order: connected, known, then the strongest; networks without a name (hidden) are dropped.
export function wifiNodes(networks, max = Infinity) {
    const rank = net => net.connected ? 0 : net.known ? 1 : 2;
    const seen = new Set();
    return networks
        .filter(net => net.name)
        .sort((a, b) => rank(a) - rank(b) || (b.signal ?? 0) - (a.signal ?? 0))
        .filter(net => !seen.has(net.name) && seen.add(net.name))
        .slice(0, max)
        .map(net => ({
            id: net.name,
            name: net.name,
            signal: percent(net.signal),
            glyph: wifiIcon({ enabled: true, signal: net.signal ?? 0 }), // same field as BT nodes: one glyph slot in the card and core
            kind: securityKind(net.security),
            known: !!(net.known || net.connected), // inner ring; a network only in range sits on the outer one
            connected: !!net.connected,
            busy: !!net.busy, // connecting or disconnecting
        }));
}

export function wifiActions({ connected, known, kind }) {
    if (connected)
        return ["disconnect", "forget"];
    if (known)
        return ["connect", "forget"];
    if (kind === "psk")
        return ["password"];
    return kind === "open" ? ["connect"] : ["program"];
}

// reason: ConnectionFailReason enum value
export function wifiFailure(reason) {
    const name = FAIL_REASONS[reason];
    if (name === "NoSecrets" || name === "WifiAuthTimeout")
        return { text: "Wrong password", askPassword: true };
    if (name === "WifiNetworkLost")
        return { text: "Network lost", askPassword: false };
    return { text: "Connection failed", askPassword: false };
}

// --- Bluetooth -----------------------------------------------------------------------------

// icon: BlueZ device icon name (freedesktop names like "audio-headset"); the name helps when BlueZ has none.
export function btGlyph(icon, name) {
    const type = (icon ?? "").toLowerCase();
    const label = (name ?? "").toLowerCase();
    if (/headset|headphone/.test(type) || /headphone|buds|pods/.test(label))
        return BT_GLYPHS.headphones;
    if (/audio|speaker/.test(type) || /speaker|sound/.test(label))
        return BT_GLYPHS.speaker;
    if (/phone/.test(type))
        return BT_GLYPHS.phone;
    if (/mouse/.test(type))
        return BT_GLYPHS.mouse;
    if (/keyboard/.test(type))
        return BT_GLYPHS.keyboard;
    if (/gaming|joystick/.test(type))
        return BT_GLYPHS.gamepad;
    if (/computer/.test(type))
        return BT_GLYPHS.computer;
    return BT_GLYPHS.device;
}

// devices: [{ address, name (alias), deviceName (BlueZ name), icon, connected, paired, trusted,
// batteryAvailable, battery (0–1) }]. A new device that only has an address is scan noise (serpantinum).
export function btNodes(devices, max = Infinity) {
    const rank = dev => dev.connected ? 0 : dev.paired ? 1 : 2;
    return devices
        .filter(dev => dev.address && (dev.paired || dev.connected || dev.deviceName))
        .map(dev => ({
            id: dev.address,
            name: dev.deviceName || dev.name || dev.address,
            glyph: btGlyph(dev.icon, dev.deviceName || dev.name),
            connected: !!dev.connected,
            paired: !!dev.paired,
            trusted: !!dev.trusted,
            known: !!(dev.paired || dev.connected), // inner ring; a new device sits on the outer one
            battery: dev.batteryAvailable ? percent(dev.battery) : null,
            busy: !!dev.busy, // pairing, connecting or disconnecting
        }))
        .sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name))
        .slice(0, max);
}

// profile: parseCards() entry of the device, or null
export function btActions({ connected, paired, trusted }, profile) {
    if (!paired && !connected)
        return ["pair"];
    const actions = [connected ? "disconnect" : "connect"];
    if (connected && profile?.other)
        actions.push("profile");
    actions.push(trusted ? "untrust" : "trust", "forget");
    return actions;
}

// --- A2DP ↔ HFP (D3: pactl, serpantinum network/bluetooth_panel_logic.sh) -----------------

export function profileKind(name) {
    if (!name)
        return null;
    if (name.startsWith("a2dp"))
        return "a2dp";
    if (name.startsWith("headset") || name.startsWith("hfp") || name.startsWith("hsp"))
        return "hfp";
    return null;
}

export function profileLabel(kind) {
    return kind === "a2dp" ? "Hi-Fi (A2DP)" : "Headset (HFP)";
}

// text: output of `pactl -f json list cards`. Returns { "<address lower case>": { card, active, a2dp, hfp,
// other } }: a2dp / hfp = the available profile of that kind with the highest priority, other = the one
// to switch to (null while the active profile is neither, or the device has only one kind).
export function parseCards(text) {
    let cards;
    try {
        cards = JSON.parse(text);
    } catch (e) {
        return {};
    }
    if (!Array.isArray(cards))
        return {};
    const result = {};
    cards.filter(card => (card.name ?? "").startsWith("bluez_card.")).forEach(card => {
        const address = (card.properties?.["api.bluez5.address"] ?? card.name.slice("bluez_card.".length).replace(/_/g, ":")).toLowerCase();
        const best = kind => {
            const names = Object.keys(card.profiles ?? {}).filter(name => profileKind(name) === kind && card.profiles[name].available !== false);
            names.sort((a, b) => (card.profiles[b].priority ?? 0) - (card.profiles[a].priority ?? 0));
            return names[0] ?? null;
        };
        const active = profileKind(card.active_profile);
        const a2dp = best("a2dp");
        const hfp = best("hfp");
        result[address] = {
            card: card.name,
            active,
            a2dp,
            hfp,
            other: active === "a2dp" ? hfp : active === "hfp" ? a2dp : null,
        };
    });
    return result;
}

// --- texts of the core ----------------------------------------------------------------------

const KIND_NAMES = { open: "Open", psk: "Secured", program: "Enterprise" };

// tab: "wifi" | "bt"; node: wifiNodes() / btNodes() entry; profile: parseCards() entry or null
export function statusLine(tab, node, profile) {
    if (tab === "wifi") {
        const state = node.connected ? "Connected" : node.known ? "Saved" : KIND_NAMES[node.kind];
        return `${state} · ${node.signal}%`;
    }
    if (!node.connected)
        return node.paired ? "Paired" : "New";
    const parts = ["Connected"];
    if (node.battery !== null && node.battery !== undefined)
        parts.push(`${node.battery}%`);
    if (profile?.active)
        parts.push(profileLabel(profile.active));
    return parts.join(" · ");
}

export function emptyLine(tab, moduleOn) {
    if (moduleOn)
        return "Scanning…";
    return tab === "wifi" ? "Wi-Fi is off" : "Bluetooth is off";
}

export function actionLabel(action, profile) {
    if (action === "profile")
        return profileLabel(profileKind(profile?.other));
    return ACTION_LABELS[action];
}

// Actions a double click on a node may run: the node's first button (ticket 26). A connected node
// disconnects (user, 2026-10-08); a password or pairing-code prompt in the core is never answered.
const DOUBLE_CLICK = ["connect", "disconnect", "password", "program", "pair"];

// actions: the core's buttons once the node is selected (wifiActions / btActions, or a prompt's);
// busy: the node is connecting, disconnecting or pairing. Returns the action, or null for nothing.
export function doubleClickAction(actions, busy) {
    if (busy || !DOUBLE_CLICK.includes(actions[0]))
        return null;
    return actions[0];
}

// The core's action buttons in rows of two; each row is centred, so a lone third button sits in the
// middle, not under the left one (user, 2026-10-06).
export function actionRows(actions) {
    const rows = [];
    for (let i = 0; i < actions.length; i += 2)
        rows.push(actions.slice(i, i + 2));
    return rows;
}

// --- orbit geometry (serpantinum: singleBaseAngle, singleRadX/Y; the outer ring is ringShift in Orbit.qml) ---

// Place of node `index` of `count` on the orbit, as an angle from the right (rad; y grows downwards).
// The first `connected` nodes (wifiNodes and btNodes put connected ones first) sit together around
// the top, the first node alone is straight on top (user, 2026-10-06: "connected always on top").
export function slotAngle(index, count, connected = 0) {
    const step = Math.PI * 2 / Math.max(1, count);
    return -Math.PI / 2 + (index - Math.max(0, connected - 1) / 2) * step;
}

// Offset of the point at angle `theta` on an ellipse with radii `rx`, `ry`.
export function ellipsePoint(theta, rx, ry) {
    return { x: Math.cos(theta) * rx, y: Math.sin(theta) * ry };
}

// `to` shifted by whole turns to lie nearest `from`: a node gliding to its new place after the list
// changed goes the short way round, never a whole lap (user, 2026-10-06: nodes jumped).
export function nearestAngle(from, to) {
    const turn = Math.PI * 2;
    return to + Math.round((from - to) / turn) * turn;
}

// --- wobble (user, 2026-10-06): each node drifts slightly towards and away from the core ------

// FNV-1a hash of a node id with murmur3's final mix (FNV alone gave similar names similar phases),
// 0 … 1: a stable phase and pace per node, whatever its place in the list.
function idFraction(id, salt) {
    let hash = 2166136261 ^ salt;
    for (const char of id)
        hash = Math.imul(hash ^ char.codePointAt(0), 16777619);
    hash = Math.imul(hash ^ (hash >>> 16), 0x85ebca6b);
    hash = Math.imul(hash ^ (hash >>> 13), 0xc2b2ae35);
    return ((hash ^ (hash >>> 16)) >>> 0) / 4294967296;
}

// Radial offset (px) of node `id` at `time` (s): a sine of `amplitude` px whose phase and period
// (`period` ms ± 12%) come from the id, so nodes are out of step and the orbit never breathes as one.
// `inStep`: every node with the same phase and period; Theme.orbit.wobble uses it (user, 2026-10-06).
export function wobble(id, time, { amplitude, period, inStep = false }) {
    const phase = inStep ? 0 : idFraction(id, 0) * Math.PI * 2;
    const seconds = period / 1000 * (inStep ? 1 : 0.88 + 0.24 * idFraction(id, 1));
    return amplitude * Math.sin(phase + time / seconds * Math.PI * 2);
}

// --- lightning (ticket 13; serpantinum nodeLinesCanvas: three wavy strands per node, 25 ms) ---

// Strand geometry from serpantinum, in px: a strand ends under the
// node's card at least `endInside` from each of its edges (more than half the glow plus the jitter),
// has `steps` segments; `fadeDistance` is where a strand gets its dimmest and thinnest. `jitter`
// bounds the sideways shake, which is not damped at the ends. serpantinum stopped 26 px short of the
// node's centre; ours stopped 6 px short of the card's edge, which showed as a gap (user, 2026-10-06).
export const BOLT = { endInside: 12, steps: 22, fadeDistance: 420, jitter: 3.75 };

// Per layer, bottom to top: a wave sin(speed·time + freq·t + phase·seed + shift) damped towards both
// ends, plus a shake sin(shakeSpeed·time + shakeStep·step + shakeShift) growing for closer nodes.
// Width and alpha as in serpantinum (glow 0.22, mid 0.55, core 0.95).
const BOLT_LAYERS = [
    { layer: "glow", speed: 3.4, freq: 9, phase: 1, shift: 0, amp: 9, shakeSpeed: 12, shakeStep: 1, shakeShift: 0, shake: 2.0,
      width: f => 4.5 + f * 3.0, alpha: 0.22 },
    { layer: "mid", speed: 2.5, freq: 6, phase: -1, shift: 0, amp: 5.5, shakeSpeed: 10, shakeStep: -1, shakeShift: Math.PI / 2, shake: 2.5,
      width: f => 2 * (1.0 + f * 1.2), alpha: 0.55 },
    { layer: "core", speed: -1.5, freq: 8, phase: 2, shift: Math.PI / 2, amp: 7, shakeSpeed: 14, shakeStep: 1, shakeShift: 0, shake: 1.8,
      width: f => 1.0 + f * 1.2, alpha: 0.95 },
];

// A node gets a strand while connected.
export function getsBolt(node) {
    return node?.connected ?? false;
}

// Whether any node gets a strand, i.e. whether the lightning runs at all.
export function hasBolts(nodes) {
    return nodes.some(getsBolt);
}

// Strands of one bolt from the core at `from` to the centre `to` of a node's `card` ({ width, height })
// at `time` (s), starting `start` px from `from`; `seed` (node index) keeps bolts of different nodes
// out of step. `reach` 0 → 1 grows
// the bolt out of the core, `fade` 0 → 1 scales its alpha. Returns
// [{ layer, width, alpha, points: [{ x, y }] }] in BOLT_LAYERS order (glow, mid, core — Orbit.qml
// colours them by that position), or [] when nothing is left to draw.
export function boltStrands(from, to, time, seed, { start, card, reach, fade }) {
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const distance = Math.hypot(dx, dy);
    if (distance < 10)
        return [];
    const cos = dx / distance;
    const sin = dy / distance;
    // from the card's centre, along the strand, to the edge of the card shrunk by endInside
    const halfWidth = Math.max(0, card.width / 2 - BOLT.endInside);
    const halfHeight = Math.max(0, card.height / 2 - BOLT.endInside);
    const inCard = Math.min(cos ? halfWidth / Math.abs(cos) : Infinity, sin ? halfHeight / Math.abs(sin) : Infinity);
    const length = (distance - inCard - start) * Math.min(1, reach);
    if (length <= 0)
        return [];
    const sx = from.x + cos * start;
    const sy = from.y + sin * start;
    const proximity = Math.max(0, 1 - distance / BOLT.fadeDistance); // 1 at the core, 0 at fadeDistance
    const alpha = (0.35 + proximity * 0.65) * fade;
    return BOLT_LAYERS.map(layer => {
        const points = [{ x: sx, y: sy }];
        for (let step = 1; step <= BOLT.steps; step++) {
            const t = step / BOLT.steps;
            const along = length * t;
            const wave = Math.sin(layer.speed * time + layer.freq * t + layer.phase * seed + layer.shift) * layer.amp * Math.sin(t * Math.PI);
            const shake = (Math.sin(layer.shakeSpeed * time + layer.shakeStep * step + layer.shakeShift) - 0.5) * layer.shake * proximity;
            const side = wave + shake;
            points.push({ x: sx + cos * along - sin * side, y: sy + sin * along + cos * side });
        }
        return { layer: layer.layer, width: layer.width(proximity), alpha: alpha * layer.alpha, points };
    });
}

// --- pairing with a code (orbit/bt-pair.py: BlueZ agent for a pairing the Orbita starts) ------

export const PAIR_FAILED = "Pairing failed";

// line: one JSON line of bt-pair.py. Returns { event, code, text? } or null for anything else.
// BlueZ passkeys are numbers shown as six digits; a legacy PIN code is a string.
export function pairEvent(line) {
    let data;
    try {
        data = JSON.parse(line);
    } catch (e) {
        return null;
    }
    const event = data?.event;
    if (event === "confirm" || event === "display") {
        const code = data.passkey !== undefined ? String(data.passkey).padStart(6, "0") : String(data.pincode ?? "");
        return { event, code };
    }
    if (event === "done")
        return { event, code: "" };
    if (event === "failed")
        return { event, code: "", text: data.error === "pin" ? "Needs a PIN — use the Bluetooth manager" : PAIR_FAILED };
    return null;
}

// prompt: pairEvent() of a "confirm" or "display" request
export function pairActions(prompt) {
    return prompt.event === "confirm" ? ["confirm", "deny"] : ["deny"];
}

// text in the core under the code
export function pairPromptText(prompt) {
    return prompt.event === "confirm" ? "Same code on the device?" : "Type this code on the device";
}
