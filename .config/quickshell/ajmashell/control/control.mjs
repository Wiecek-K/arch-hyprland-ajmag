// Pure logic of the Centrum sterowania (ticket 14, D1, D4) and of the audio popup under the Bar's volume islands:
// PipeWire devices and per-app streams (B10 §1), slider ↔ volume, built-in panel brightness through logind (B10 §2.1a),
// the Wi-Fi / BT rows. A JS module (not QML) so tools/test-control-center.mjs can test it with node.
// Own implementation; device / stream split by the PwNode flags (isSink, isStream) after research B10 §1.2–1.3.
// Nodes come in as plain objects: { id, name, description, nickname, isSink, isStream, audio (bool), properties }.
// Device kinds, short names and app icon names: faza C ticket 17 (prototype variants C and A, user 2026-11-08).

import { LIMIT } from "../bar/audio.mjs";

const WHEEL_STEP = 0.05; // of the slider track per wheel notch, like the Bar's ±5%
const MIN_BRIGHTNESS = 0.01; // of max; 0 turns the eDP-1 panel black and the slider can no longer be seen
// media.name values that only say "a stream" (Firefox/Zen send "AudioStream")
const GENERIC_MEDIA = ["AudioStream", "Playback", "playback", "Audio", "audio"];
const HEADPHONES = ["headphone", "headset", "hands-free"];

// Nerd Font (Material Design) glyphs of the audio section
export const AUDIO_ICON = {
    speaker: "\u{f04c3}",
    headphones: "\u{f02cb}",
    monitor: "\u{f0379}",
    bluetooth: "\u{f00b0}",
    effects: "\u{f066a}",
    mic: "\u{f036c}",
    webcam: "\u{f05a0}",
    apps: "\u{f003b}",
    app: "\u{f075a}", // app without an icon in the icon theme
    check: "\u{f012c}",
    open: "\u{f0143}", // device list open (chevron up)
    closed: "\u{f0140}",
};

export function deviceLabel(n) {
    return n.description || n.nickname || n.name;
}

// "… Analog Stereo" / "… Digital Stereo (HDMI 4) [Q27G3XMN]" → the chip's name without the profile and the port
function chipName(description) {
    return description
        .replace(/\[.*?\]/g, "")
        .replace(/\(HDMI \d+\)/g, "")
        .replace(/\s+(Analog|Digital|Pro)( Stereo| Surround\S*| Mono)?\s*$/i, "")
        .replace(/\s+HDMI\/DP Audio Controller.*$/i, "")
        .trim();
}

// What a device is: { icon, title (short name), subtitle (what it is + the chip) }. The long description is
// cut off in a 400 px row ("800 Series Chipset Family Audio Context Engine (ACE) Analog Stereo"), so the title
// comes from what tells the devices apart: the monitor (node.nick) for HDMI, the BT device's name, Easy Effects.
export function deviceKind(n, microphone) {
    const p = n.properties || {};
    const name = n.name || "";
    const description = deviceLabel(n);
    const nick = p["node.nick"] || n.nickname || "";
    const formFactor = p["device.form-factor"] || "";
    if (/^easyeffects_/.test(name))
        return { icon: AUDIO_ICON.effects, title: "Easy Effects",
            subtitle: microphone ? "Effects on the microphone" : "Effects: equalizer, compressor" };
    if (name.startsWith("bluez_"))
        return { icon: HEADPHONES.includes(formFactor) ? AUDIO_ICON.headphones : AUDIO_ICON.bluetooth,
            title: description, subtitle: "Bluetooth" };
    if (/hdmi|displayport/i.test(name + " " + description)) {
        const port = (description.match(/\((HDMI \d+)\)/) || [])[1] || "HDMI";
        return { icon: AUDIO_ICON.monitor, title: nick && !/hdmi/i.test(nick) ? nick : "HDMI monitor",
            subtitle: port + " · " + chipName(description) };
    }
    if (formFactor === "webcam")
        return { icon: AUDIO_ICON.webcam, title: nick || chipName(description), subtitle: "Webcam" };
    if (HEADPHONES.includes(formFactor))
        return { icon: AUDIO_ICON.headphones, title: nick || chipName(description), subtitle: chipName(description) };
    // USB audio (a podcast mic with a headphone jack, a USB DAC): its own name; the onboard jack keeps "Jack …"
    if (p["device.bus"] === "usb") {
        const onMic = formFactor === "microphone";
        return { icon: microphone ? AUDIO_ICON.mic : onMic ? AUDIO_ICON.headphones : AUDIO_ICON.speaker,
            title: nick || chipName(description),
            subtitle: microphone || !onMic ? "USB" : "USB · headphone output" };
    }
    const codec = nick.replace(/\s+Analog$/i, "");
    return { icon: microphone ? AUDIO_ICON.mic : AUDIO_ICON.speaker,
        title: microphone ? "Jack input" : "Jack output (speakers)",
        subtitle: (codec ? codec + " · " : "") + chipName(description) };
}

// Names to look up for an app's icon (DesktopEntries, then the icon theme), best first. Zen sends no
// application.icon-name, only application.process.binary "zen-bin". Idea after end-4's VolumeMixerEntry.qml.
export function appIconCandidates(p) {
    const binary = (p["application.process.binary"] || "").replace(/-(bin|wrapped)$/, "");
    return [p["application.icon-name"], p["application.id"], binary, (p["application.name"] || "").toLowerCase(), p["node.name"]]
        .filter((name, i, all) => name && all.indexOf(name) === i);
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

// Ticket c20: brightness only with an enabled built-in panel (eDP, LVDS, DSI) and a backlight device. Hyprland lists
// enabled outputs only; their names change (DP-5 became DP-6), so match the type at the start of the name only.
// Returns the first backlight device by name (the order of `ls /sys/class/backlight`), or "" for none.
const BUILT_IN = /^(eDP|LVDS|DSI)-/;

export function backlightDevice(monitorNames, devices) {
    if (!monitorNames.some(name => BUILT_IN.test(name)))
        return "";
    return devices.filter(device => device).sort()[0] ?? "";
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
