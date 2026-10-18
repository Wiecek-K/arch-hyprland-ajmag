// Pure logic of the Centrum sterowania (ticket 14, D1, D4) and of the audio popup under the Bar's volume islands:
// PipeWire devices and per-app streams (B10 §1), slider ↔ volume, eDP-1 brightness through logind (B10 §2.1a),
// the Wi-Fi / BT rows. A JS module (not QML) so tools/test-control-center.mjs can test it with node.
// Own implementation; device / stream split by the PwNode flags (isSink, isStream) after research B10 §1.2–1.3.
// Nodes come in as plain objects: { id, name, description, nickname, isSink, isStream, audio (bool), properties }.

import { LIMIT } from "../bar/audio.mjs";

const WHEEL_STEP = 0.05; // of the slider track per wheel notch, like the Bar's ±5%
const MIN_BRIGHTNESS = 0.01; // of max; 0 turns the eDP-1 panel black and the slider can no longer be seen
// media.name values that only say "a stream" (Firefox/Zen send "AudioStream")
const GENERIC_MEDIA = ["AudioStream", "Playback", "playback", "Audio", "audio"];

export function deviceLabel(n) {
    return n.description || n.nickname || n.name;
}

// Hardware outputs (sinks) or inputs (sources), by name. Video sources have no audio.
export function audioDevices(nodes, microphone) {
    return nodes.filter(n => n.audio && !n.isStream && n.isSink === !microphone)
        .sort((a, b) => deviceLabel(a).localeCompare(deviceLabel(b)));
}

// pavucontrol opens a "Peak detect" recording stream per device for its level meters
function isMeter(n) {
    return n.properties["media.name"] === "Peak detect" || n.properties["stream.monitor"] === "true";
}

// Apps playing (sink streams) or recording (source streams).
export function audioStreams(nodes, microphone) {
    return nodes.filter(n => n.audio && n.isStream && n.isSink === !microphone && !isMeter(n));
}

export function streamText(n) {
    const label = n.properties["application.name"] || deviceLabel(n);
    const media = n.properties["media.name"] || "";
    const detail = media && media !== label && !GENERIC_MEDIA.includes(media) ? media : "";
    return { label, detail };
}

function clamp(value, low, high) {
    return Math.max(low, Math.min(high, value));
}

// Slider position 0–1 → volume 0–LIMIT %, whole percent (as pamixer and the Bar's wheel).
export function volumeAt(position) {
    return Math.round(clamp(position, 0, 1) * LIMIT) / 100;
}

export function volumePosition(volume) {
    return clamp((volume ?? 0) * 100 / LIMIT, 0, 1);
}

export function wheelPosition(position, step) {
    return Math.round(clamp(position + step * WHEEL_STEP, 0, 1) * 100) / 100;
}

export function brightnessPercent(raw, max) {
    return max > 0 ? Math.round(raw * 100 / max) : 0;
}

export function brightnessRaw(position, max) {
    return Math.round(clamp(position, MIN_BRIGHTNESS, 1) * max);
}

// logind lets the session's user set the backlight without the video group (B10 §2.1a, checked 2026-10-07)
export function brightnessCommand(device, raw) {
    return ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto",
        "org.freedesktop.login1.Session", "SetBrightness", "ssu", "backlight", device, String(raw)];
}

// D4: the row shows the connection's name; the state when there is none
export function wifiRowText({ enabled, name, wiredName }) {
    if (!enabled)
        return "Off";
    return name || wiredName || "Not connected";
}

export function btRowText({ enabled, names }) {
    if (!enabled)
        return "Off";
    return names.length > 0 ? names.join(", ") : "No device";
}
