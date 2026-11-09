// Pure logic of the media island and popup (ticket 17): which MPRIS player is shown, labels for the player
// chooser, time and progress texts, the seek target and the control icons.
// A JS module (not QML) so tools/test-media.mjs can test it with node.
// Own implementation; player choice after serpantinum src/quickshell/singletons/audio/MprisController.qml
// (playing first, then any) and MusicPopup.qml (manual choice, "name (title)" for duplicate names), idea only:
// https://github.com/ilyamiro/serpantinum@67ee7053f2a555684e73a39a795db60750260d8d

// playerctld re-exports the other players under its own name: showing it would duplicate one of them
const IGNORED = ["org.mpris.MediaPlayer2.playerctld"];

export const ICONS = {
    previous: "\u{f04ae}",
    play: "\u{f040a}",
    pause: "\u{f03e4}",
    next: "\u{f04ad}",
    music: "\u{f0388}", // cover placeholder
};
// the play / pause button shows either; its slot is as wide as the wider one
export const PLAY_ICONS = [ICONS.play, ICONS.pause];

// Players worth showing: a track to name or playback going on. A browser keeps a player with no metadata
// after its media tab closed — that one does not count, so the island hides.
export function candidates(players) {
    return players.filter(p => IGNORED.indexOf(p.dbusName) < 0 && (p.trackTitle || p.isPlaying));
}

// The player the island and popup show. `chosen`: bus name picked by the user in the popup — wins while present.
// `current`: bus name shown so far — kept while nothing plays, so pausing one player does not jump to another.
export function pick(players, { chosen, current }) {
    const list = candidates(players);
    const byName = name => list.find(p => p.dbusName === name);
    return byName(chosen) ?? list.find(p => p.isPlaying) ?? byName(current) ?? list[0] ?? null;
}

function baseName(p) {
    // org.mpris.MediaPlayer2.firefox.instance_1_544 → firefox
    return p.identity || p.desktopEntry || (p.dbusName ?? "").split(".")[3] || "";
}

// .desktop id of the player's app, whose window a double click focuses (ticket c14): MPRIS DesktopEntry ("spotify";
// "zen" for Zen's org.mpris.MediaPlayer2.firefox… player), else the app part of the bus name. Apps.goToApp matches
// it to the window class as the launcher does (apps.mjs showRequests).
export function appId(p) {
    if (!p)
        return "";
    return (p.desktopEntry || "").replace(/\.desktop$/, "") || (p.dbusName ?? "").split(".")[3] || "";
}

// Name in the player chooser; two players of one app (two browser tabs) are told apart by their track.
export function label(p, all) {
    const name = baseName(p);
    const same = all.filter(o => baseName(o) === name).length;
    return same > 1 && p.trackTitle ? `${name} · ${p.trackTitle}` : name;
}

export function title(p, all) {
    if (!p)
        return "";
    return p.trackTitle || label(p, all);
}

export function artist(p) {
    return p?.trackArtist ?? "";
}

export function formatTime(seconds) {
    const total = Math.max(0, Math.floor(seconds || 0));
    const h = Math.floor(total / 3600);
    const m = Math.floor(total / 60) % 60;
    const s = String(total % 60).padStart(2, "0");
    return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${s}` : `${m}:${s}`;
}

export function timeText(position, length) {
    return length > 0 ? `${formatTime(position)} / ${formatTime(length)}` : formatTime(position);
}

export function progress(position, length) {
    return length > 0 ? Math.max(0, Math.min(1, position / length)) : 0;
}

export function seekPosition(fraction, length) {
    return Math.max(0, Math.min(1, fraction)) * length;
}

// Position bar of the preview and popup. Only a player that reports the track's length has a trustworthy
// position: Zen / Firefox on a YouTube page without position state sends no mpris:length and keeps Position at 0,
// and Quickshell then reports length = its own estimate of the position (bar always full, seeking to nonsense).
// Such a track shows no time and cannot be seeked (user, 2026-10-07: seeking on Zen / YouTube did not work).
// YouTube in Zen also drops the length after a seek until the next pause / play; `knownLength` = the length
// remembered for this track (Media.qml) stands in then — the position is Quickshell's estimate from the seek
// target, which is right (user, 2026-10-07: "czas… przestał się wyświetlać do momentu aż zrobiłem pause > unpause").
// `p`: { position, length, lengthSupported, canSeek } (MprisPlayer fields) or null.
export function timeline(p, knownLength = 0) {
    const length = p?.lengthSupported && p.length > 0 ? p.length : p ? knownLength : 0;
    if (!(length > 0))
        return { known: false, position: 0, length: 0, fraction: 0, text: "", seekable: false };
    const position = Math.max(0, Math.min(p.position, length)); // the estimate runs on past the track's end
    return {
        known: true,
        position,
        length,
        fraction: progress(position, length),
        text: timeText(position, length),
        seekable: !!p.canSeek,
    };
}

// one track of one player, for the remembered length
export function trackKey(p) {
    return p ? `${p.dbusName}\n${p.trackTitle}` : "";
}

export function playIcon(playing) {
    return playing ? ICONS.pause : ICONS.play;
}

// Faza C ticket 29: keys of the media popup (map: user, 2026-11-09). Qt::Key codes, since node has no `Qt`
// (values from qnamespace.h); MediaPopup.qml passes event.key and whether Shift is held.
export const QT_KEY = {
    escape: 0x01000000,
    tab: 0x01000001,
    backtab: 0x01000002, // Shift+Tab
    return: 0x01000004,
    enter: 0x01000005, // keypad
    left: 0x01000012,
    up: 0x01000013,
    right: 0x01000014,
    down: 0x01000015,
    space: 0x20,
    comma: 0x2c,
    period: 0x2e,
};

// key → action of the popup, or null. Shift+← / Shift+→ and , / . change the track; ← / → seek.
export function keyAction(key, shift) {
    const K = QT_KEY;
    switch (key) {
    case K.space: return "togglePlaying";
    case K.tab: return "nextPlayer";
    case K.backtab: return "previousPlayer";
    case K.left: return shift ? "previous" : "seekBack";
    case K.right: return shift ? "next" : "seekForward";
    case K.comma: return "previous";
    case K.period: return "next";
    case K.up: return shift ? null : "volumeUp";
    case K.down: return shift ? null : "volumeDown";
    case K.return:
    case K.enter: return "goToApp";
    case K.escape: return "close";
    default: return null;
    }
}

// Tab / Shift+Tab: the player `delta` places after `current` in `players` (the chooser's pills), round the end;
// null when there is no other player to switch to.
export function cyclePlayer(players, current, delta) {
    if (players.length < 2)
        return null;
    const index = players.indexOf(current);
    if (index < 0)
        return players[0];
    return players[(index + delta + players.length) % players.length];
}

export const SEEK_STEP = 10; // s per ← / → (user, 2026-11-09)

// ← / →: target position `delta` steps from now, inside the track; null when the track cannot be seeked.
// `time`: timeline() of the shown player.
export function seekBy(time, delta) {
    if (!time.seekable)
        return null;
    return Math.max(0, Math.min(time.length, time.position + delta * SEEK_STEP));
}

export const VOLUME_STEP = 0.05; // ↑ / ↓, the player's MPRIS volume (user, 2026-11-09: the player's, not the system's)

// ↑ / ↓: the player's new volume, rounded to whole percent (no 0.1 + 0.05 drift); null when the player has no
// volume of its own (many browsers) or takes no commands.
export function volumeBy(p, delta) {
    if (!p?.volumeSupported || !p.canControl)
        return null;
    return Math.round(Math.max(0, Math.min(1, p.volume + delta * VOLUME_STEP)) * 100) / 100;
}

// Held key: seeking and volume go on with the key's auto-repeat; a repeated play / pause, player or track change
// would flicker between states, so those act on the first press only.
export function repeats(action) {
    return ["seekBack", "seekForward", "volumeUp", "volumeDown"].indexOf(action) >= 0;
}

// Faza C ticket 31: XF86Audio keys (hypr/scripts/media-key.sh → IPC `media key <verb>`, verbs as in playerctl)
// control the shown player, the one on the Bar and in the popup, not the one playerctl would pick.
// Verb → [MprisPlayer method, the flag that allows it].
const MEDIA_KEYS = {
    "play-pause": ["togglePlaying", "canTogglePlaying"],
    next: ["next", "canGoNext"],
    previous: ["previous", "canGoPrevious"],
};

// `answer` goes back to the script: "done" = the shell handled the key (even when the shown player cannot do it
// right now, e.g. no next track: no other player gets it), "none" = no shown player or an unknown verb, the script
// runs playerctl. `method`: the MprisPlayer method to call, or null.
export function mediaKey(p, verb) {
    const entry = Object.prototype.hasOwnProperty.call(MEDIA_KEYS, verb) ? MEDIA_KEYS[verb] : null;
    if (!p || !entry)
        return { answer: "none", method: null };
    return { answer: "done", method: p[entry[1]] ? entry[0] : null };
}
