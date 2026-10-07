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
// `p`: { position, length, lengthSupported, canSeek } (MprisPlayer fields) or null.
export function timeline(p) {
    if (!p || !p.lengthSupported || !(p.length > 0))
        return { known: false, position: 0, length: 0, fraction: 0, text: "", seekable: false };
    const position = Math.max(0, Math.min(p.position, p.length)); // the estimate runs on past the track's end
    return {
        known: true,
        position,
        length: p.length,
        fraction: progress(position, p.length),
        text: timeText(position, p.length),
        seekable: !!p.canSeek,
    };
}

export function playIcon(playing) {
    return playing ? ICONS.pause : ICONS.play;
}
