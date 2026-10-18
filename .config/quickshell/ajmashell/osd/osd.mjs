// Pure logic of the OSD (ticket 15): what the volume and brightness keys show.
// Icon and percent as on the Bar's volume island, slider position on the scale of the Centrum sterowania
// (volume: full = 150%), so the three agree. A JS module (not QML) so tools/test-osd.mjs can test it with node.
// Own implementation.

import * as Audio from "../bar/audio.mjs";
import { volumePosition } from "../control/control.mjs";

export const BRIGHTNESS_ICON = "\u{f00df}"; // as the Centrum's brightness slider

// audio: { volume, muted, formFactor } of the default output, or null when there is none
export function volumeView(audio) {
    if (!audio)
        return { icon: Audio.icon({ volume: 0, muted: false }), position: 0, text: "--", muted: false };
    return {
        icon: Audio.icon(audio),
        position: volumePosition(audio.volume),
        text: `${Audio.percent(audio.volume)}%`,
        muted: audio.muted
    };
}

// percent: the new level brightness.sh has set, 0–100
export function brightnessView(percent) {
    const level = Math.max(0, Math.min(100, Math.round(percent) || 0));
    return { icon: BRIGHTNESS_ICON, position: level / 100, text: `${level}%`, muted: false };
}
