// Pure logic of screen recording on the Bar (faza C ticket cb40): the state file written by
// ~/.config/hypr/scripts/screen-record.sh and the time the privacy dot shows while recording.
// A JS module (not QML) so tools/test-recording.mjs in the project can test it with node.
// Own implementation.

// "pid<TAB>start (s since the epoch)<TAB>file" → { pid, startedAt, path }; null = not recording (no file, empty,
// broken). The path is the rest of the line, so it may hold tabs and spaces.
export function parseState(text) {
    const line = text.split("\n")[0];
    const first = line.indexOf("\t");
    const second = line.indexOf("\t", first + 1);
    if (first < 0 || second < 0)
        return null;
    const pid = Number(line.slice(0, first));
    const startedAt = Number(line.slice(first + 1, second));
    const path = line.slice(second + 1);
    if (!Number.isInteger(pid) || pid <= 0 || !Number.isFinite(startedAt) || path === "")
        return null;
    return { pid, startedAt, path };
}

// seconds since the start → "0:07", "12:34", "1:02:03"
export function elapsedText(seconds) {
    const total = Math.max(0, Math.floor(seconds));
    const h = Math.floor(total / 3600), m = Math.floor(total / 60) % 60, s = total % 60;
    const two = n => String(n).padStart(2, "0");
    return h > 0 ? `${h}:${two(m)}:${two(s)}` : `${m}:${two(s)}`;
}

// the text whose width the label takes: every digit as 0 (tabular digits are all as wide), so the island does not
// change its width every second; under an hour always room for the tens of minutes ("0:07" → "00:00", the time
// right-aligned in it; user, 2026-11-10), so it changes only at one hour
export function widthTemplate(text) {
    const zeros = text.replace(/[0-9]/g, "0");
    return zeros === "0:00" ? "00:00" : zeros;
}
