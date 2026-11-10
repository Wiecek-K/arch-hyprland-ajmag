// Pure logic of the Bar's privacy dot (faza C ticket 05): which apps use the microphone, the camera or share the
// screen, as one row per app. A JS module (not QML) so tools/test-privacy.mjs in the project can test it with node.
// Rules adapted from DankMaterialShell quickshell/Services/PrivacyService.qml (microphoneActive, cameraActive,
// screensharingActive, looksLikeScreencast):
// https://github.com/AvengeMedia/DankMaterialShell/blob/4a51cd642ca08facf4c78940ef393fc1e880bcd1/quickshell/Services/PrivacyService.qml
// Copyright (c) 2025 Avenge Media LLC — MIT
// Changes: which app, not only whether (user, 2026-11-10: a click shows the app); microphone without DMS's name
// test (/cava|monitor|system/), by stream.monitor / stream.capture.sink / media.category instead, and a muted stream
// still counts (the app has the microphone open); camera vs screen by the source a video stream is linked to (DMS:
// stream.is-live and media.role); screencast regex without "obs" and a bare "screen" (OBS's Video/Source is its
// virtual camera); no desktop-audio-as-screencast rule; plus the apps holding /dev/video* (camera-users.sh).
// SPDX-License-Identifier: MIT

const KINDS = ["mic", "camera", "screen"];
const LABELS = { mic: "mikrofon", camera: "kamera", screen: "ekran" };

// nodes: [{ id, props }] (props of a bound PwNode); links: [{ source, target }] (node ids);
// cameraApps: process names holding /dev/video* open (camera-users.sh)
// → [{ app, kinds: ["mic" | "camera" | "screen", …] }]
export function rows(nodes, links, cameraApps) {
    const byId = new Map(nodes.map(n => [n.id, n.props ?? {}]));
    const sources = id => links.filter(l => l.target === id).map(l => byId.get(l.source)).filter(p => p);
    const readers = id => links.filter(l => l.source === id).map(l => byId.get(l.target)).filter(p => p);
    const found = []; // [app, kind] in node order
    for (const n of nodes) {
        const props = n.props ?? {};
        if (isMicStream(props)) {
            found.push([appName(props), "mic"]);
        } else if (props["media.class"] === "Stream/Input/Video") {
            // a consumer reads either a camera or a screencast; unlinked = not capturing yet
            const from = sources(n.id);
            if (from.some(isScreencast))
                found.push([appName(props), "screen"]);
            else if (from.length > 0)
                found.push([appName(props), "camera"]);
        } else if (isScreencast(props) && readers(n.id).length === 0) {
            // the portal made the stream but no app reads it yet: share started, app unknown
            found.push(["", "screen"]);
        }
    }
    for (const app of cameraApps)
        found.push([app, "camera"]);

    // one row per app (case-insensitive: PipeWire says "Chromium", the process is "chromium")
    const out = [];
    for (const [app, kind] of found) {
        let row = out.find(r => r.app.toLowerCase() === app.toLowerCase());
        if (!row)
            out.push(row = { app, kinds: [] });
        if (!row.kinds.includes(kind))
            row.kinds.push(kind);
    }
    for (const row of out)
        row.kinds.sort((a, b) => KINDS.indexOf(a) - KINDS.indexOf(b));
    return out;
}

// "Firefox — mikrofon, kamera"
export function rowText(row) {
    return (row.app || "Nieznana aplikacja") + " — " + row.kinds.map(k => LABELS[k]).join(", ");
}

function appName(props) {
    return props["application.name"] || props["application.process.binary"] || props["node.description"]
        || props["node.name"] || "";
}

// A screencast stream of the desktop portal (xdg-desktop-portal-hyprland: node xdph-streaming-N) or another
// compositor's. DMS's looksLikeScreencast without "obs" and a bare "screen": OBS's Video/Source is its virtual camera.
function isScreencast(props) {
    if (props["media.class"] !== "Video/Source")
        return false;
    const text = [props["application.name"], props["node.name"], props["media.name"]].join(" ").toLowerCase();
    return /xdg-desktop-portal|xdph|xdpw|screencast|screen-cast|gnome shell|kwin|niri/.test(text);
}

// An app's capture stream. Not: "Stream/Input/Audio/Internal" (a BT headset's own node, there while it is
// connected), level meters (stream.monitor: pavucontrol, Quickshell's PwNodePeakMonitor), a sink's monitor
// (stream.capture.sink: cava, recording the desktop's sound).
function isMicStream(props) {
    return props["media.class"] === "Stream/Input/Audio"
        && props["stream.monitor"] !== "true"
        && props["stream.capture.sink"] !== "true"
        && props["media.category"] !== "Monitor";
}
