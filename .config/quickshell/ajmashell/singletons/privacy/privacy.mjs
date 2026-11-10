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
// cameraApps: processes holding /dev/video* open, [{ app, pid }] (cameraApps() of camera-users.sh's line)
// → [{ app, kinds: ["mic" | "camera" | "screen", …], pids: [process ids], clients: [PipeWire client ids] }]
//   (pids and clients find the app's window, windowFor)
export function rows(nodes, links, cameraApps) {
    const byId = new Map(nodes.map(n => [n.id, n.props ?? {}]));
    const sources = id => links.filter(l => l.target === id).map(l => byId.get(l.source)).filter(p => p);
    const readers = id => links.filter(l => l.source === id).map(l => byId.get(l.target)).filter(p => p);
    const found = []; // [app, kind, pid, client] in node order
    for (const n of nodes) {
        const props = n.props ?? {};
        if (isMicStream(props)) {
            found.push([appName(props), "mic", pidOf(props), clientOf(props)]);
        } else if (props["media.class"] === "Stream/Input/Video") {
            // a consumer reads either a camera or a screencast; unlinked = not capturing yet
            const from = sources(n.id);
            if (from.some(isScreencast))
                found.push([appName(props), "screen", pidOf(props), clientOf(props)]);
            else if (from.length > 0)
                found.push([appName(props), "camera", pidOf(props), clientOf(props)]);
        } else if (isScreencast(props) && readers(n.id).length === 0) {
            // the portal made the stream but no app reads it yet: share started, app unknown
            found.push(["", "screen", 0, 0]);
        }
    }
    for (const c of cameraApps)
        found.push([c.app, "camera", c.pid, 0]);

    // one row per app (case-insensitive: PipeWire says "Chromium", the process is "chromium")
    const out = [];
    for (const [app, kind, pid, client] of found) {
        let row = out.find(r => r.app.toLowerCase() === app.toLowerCase());
        if (!row)
            out.push(row = { app, kinds: [], pids: [], clients: [] });
        if (client > 0 && !row.clients.includes(client))
            row.clients.push(client);
        if (!row.kinds.includes(kind))
            row.kinds.push(kind);
        if (pid > 0 && !row.pids.includes(pid))
            row.pids.push(pid);
    }
    for (const row of out)
        row.kinds.sort((a, b) => KINDS.indexOf(a) - KINDS.indexOf(b));
    return out;
}

// "Firefox — mikrofon, kamera"
export function rowText(row) {
    return (row.app || "Nieznana aplikacja") + " — " + row.kinds.map(k => LABELS[k]).join(", ");
}

// camera-users.sh's line "users<TAB>pid name<TAB>…" → [{ app, pid }]; null = not such a line
export function cameraApps(line) {
    if (!line.startsWith("users"))
        return null;
    return line.split("\t").slice(1).map(entry => {
        const space = entry.indexOf(" ");
        return { app: entry.slice(space + 1), pid: parseInt(entry.slice(0, space), 10) };
    }).filter(c => c.pid > 0 && c.app !== "");
}

// The process table Privacy.qml reads when the list opens (processes.sh): `ps -e -o pid=,ppid=`, a line
// "clients", "client-id pid" per PipeWire client (its application.process.id, else pipewire.sec.pid), a line
// "tray", "pid bus-name object-path" per tray icon (StatusNotifierItem)
// → { parent: Map pid → parent pid, clientPid: Map client id → pid, tray: [{ pid, service, path }] }
export function parseProcesses(text) {
    const parent = new Map(), clientPid = new Map(), tray = [];
    let section = "ps";
    for (const line of text.split("\n")) {
        const fields = line.trim().split(/\s+/);
        if (fields.length === 1 && (fields[0] === "clients" || fields[0] === "tray")) {
            section = fields[0];
        } else if (section === "tray") {
            if (Number(fields[0]) > 0 && fields.length === 3)
                tray.push({ pid: Number(fields[0]), service: fields[1], path: fields[2] });
        } else {
            const [key, value] = fields.map(Number);
            if (key > 0 && value >= 0)
                (section === "ps" ? parent : clientPid).set(key, value);
        }
    }
    return { parent, clientPid, tray };
}

// The window a click on a row focuses (user, 2026-11-10): the nearest ancestor of one of the row's processes that
// owns a window (browsers record from a child process, pw-record from a terminal), the last used of its windows;
// without one, a window whose class matches the app name ("Google Chrome" ~ "google-chrome", "chrome" ~
// "google-chrome"). processes: parseProcesses; windows: Apps.windows. "" = none.
export function windowFor(row, processes, windows) {
    const lastUsed = list => list.sort((a, b) => rank(a) - rank(b))[0]?.address ?? "";
    const own = nearest(row, processes, pid => windows.filter(w => w.pid === pid), list => list.length > 0);
    if (own)
        return lastUsed(own);
    const app = squash(row.app);
    if (app === "")
        return "";
    return lastUsed(windows.filter(w => {
        const cls = squash(w.appId);
        return cls !== "" && (cls.includes(app) || app.includes(cls));
    }));
}

// The tray icon a click on a row without a window activates (user, 2026-11-10: Discord closed to the tray shows its
// window on the focused workspace): the icon of the nearest ancestor of the row's processes. null = none.
export function trayFor(row, processes) {
    const item = nearest(row, processes, pid => processes.tray.find(t => t.pid === pid), found => !!found);
    return item ? { service: item.service, path: item.path } : null;
}

// Walks up from each of the row's processes (its own pids, then its PipeWire clients' pids) and returns the first
// lookup(pid) that hit() accepts; null = none.
function nearest(row, processes, lookup, hit) {
    const pids = [...row.pids, ...row.clients.map(c => processes.clientPid.get(c) ?? 0)].filter(p => p > 0);
    for (const start of pids) {
        const seen = [];
        for (let pid = start; pid > 0 && !seen.includes(pid); pid = processes.parent.get(pid)) {
            seen.push(pid);
            const found = lookup(pid);
            if (hit(found))
                return found;
        }
    }
    return null;
}

function rank(w) {
    return w.focusHistory < 0 ? Infinity : w.focusHistory; // -1 = Hyprland has not told us yet
}

// "Google Chrome" and "google-chrome" → "googlechrome"
function squash(text) {
    return (text ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
}

function clientOf(props) {
    return Number(props["client.id"]) || 0;
}

function pidOf(props) {
    return parseInt(props["application.process.id"] ?? "", 10) || 0;
}

const ENGINE_NAMES = [/^webrtc voiceengine$/i, /^alsa plug-in \[/i];

// The app's name; an engine's name in place of it ("WEBRTC VoiceEngine" from Discord and other WebRTC apps, "ALSA
// plug-in [x]") gives way to the binary (user, 2026-11-10: the list said "WEBRTC VoiceEngine" for Discord).
function appName(props) {
    const name = props["application.name"] ?? "";
    const binary = props["application.process.binary"] ?? "";
    if (binary !== "" && ENGINE_NAMES.some(re => re.test(name)))
        return binary;
    return name || binary || props["node.description"] || props["node.name"] || "";
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
