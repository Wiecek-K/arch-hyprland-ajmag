// Pure logic of the Orbita (ticket 12): Wi-Fi networks and BT devices as orbit nodes, the actions
// each node offers, the A2DP ↔ HFP headset profile and node positions on the orbit.
// A JS module (not QML) so tools/test-orbit.mjs can test it with node.
// Adapted from serpantinum src/quickshell/network/NetworkPopup.qml (rebuildWifiData, rebuildBtData,
// orbit node placement) and network/bluetooth_panel_logic.sh (profile of a BlueZ card):
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// Copyright (C) 2026 Illia Miroshnichenko — AGPL-3.0-or-later
// Changes: security from Quickshell's enum (serpantinum compares raw numbers that do not match it);
// profile switching (serpantinum only shows the profile) from `pactl -f json` instead of awk + jq;
// one shared orbit for every node (no per-device cores); sorting by state, not alphabetically.
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
            icon: wifiIcon({ enabled: true, signal: net.signal ?? 0 }),
            kind: securityKind(net.security),
            known: !!net.known,
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

// --- orbit geometry (serpantinum: singleBaseAngle, ringOffset, singleRadX/Y) -----------------

// Offset of node `index` of `count` from the orbit's centre: nodes spread evenly on an ellipse
// (rx, ry), every odd node on an outer ring `ring` px further out so neighbours do not overlap;
// `angle` turns the whole orbit.
export function orbitPoint(index, count, angle, { rx, ry, ring }) {
    const theta = angle + (index / Math.max(1, count)) * Math.PI * 2;
    const extra = count > 1 && index % 2 === 1 ? ring : 0;
    return { x: Math.cos(theta) * (rx + extra), y: Math.sin(theta) * (ry + extra) };
}
