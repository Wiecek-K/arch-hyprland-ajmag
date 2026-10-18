// Pure logic of the volume islands (output volume, microphone): wheel step, icon and percent text like our old Waybar
// (waybar/Modules, dotfiles tag fallback-set-before-23 → "pulseaudio", ~/.config/hypr/scripts/volume.sh).
// A JS module (not QML) so tools/test-bar-audio.mjs can test it with node.
// Own implementation; form-factor lookup and the 150% clamp after DankMaterialShell
// quickshell/Services/AudioService.qml (sinkIcon, adjustDefaultSinkVolume), idea only:
// https://github.com/AvengeMedia/DankMaterialShell/blob/9dc5b2c5af7d18b7231f425fe0d8fa7243233109/quickshell/Services/AudioService.qml

const STEP = 5; // percent per wheel step; Waybar "scroll-step": 5, volume.sh `pamixer -i 5`
export const LIMIT = 150; // percent; volume.sh `--allow-boost --set-limit 150`

const MUTED_ICON = ""; // Waybar "format-muted"
const LEVEL_ICONS = ["", "", ""]; // Waybar "format-icons" → "default"
// Waybar "format-icons" by device; Waybar matches them in the port name + form factor,
// we only have the form factor (Quickshell's PwNode has no active port).
const DEVICE_ICONS = {
    "headphone": "",
    "hands-free": "\u{f02ce}",
    "headset": "\u{f02ce}",
    "phone": "",
    "portable": "",
    "car": "",
};
// No Bluetooth mark (Waybar "format-bluetooth"): the Bar's BT island will show the connection (user, 2026-10-01).
// every icon the island can show; its icon slot is as wide as the widest one
export const ICONS = [MUTED_ICON, ...LEVEL_ICONS, ...Object.values(DEVICE_ICONS)];

// Microphone island (ticket 08b): Waybar "pulseaudio#microphone" → format-source / format-source-muted
const MIC_ICON = "\u{f130}";
const MIC_MUTED_ICON = "\u{f131}";
export const MIC_ICONS = [MIC_ICON, MIC_MUTED_ICON];

export function percent(volume) {
    return Math.round((volume ?? 0) * 100);
}

// New { volume, muted } after one wheel step (1 = up, -1 = down).
// Muted: the first notch only unmutes, PipeWire keeps the level from before the mute
// (like volume.sh --inc/--dec; user, 2026-10-01). Up never lowers a level set above the limit elsewhere.
export function wheelStep(volume, muted, step) {
    if (muted)
        return { volume, muted: false };
    const now = percent(volume);
    const next = step > 0 ? Math.max(now, Math.min(LIMIT, now + STEP)) : Math.max(0, now - STEP);
    return { volume: next / 100, muted: false };
}

export function icon({ volume, muted, formFactor }) {
    if (muted)
        return MUTED_ICON;
    const device = DEVICE_ICONS[(formFactor ?? "").toLowerCase()];
    if (device)
        return device;
    // Waybar: percent / (100 / 3), so 0-33 low, 34-66 medium, 67+ high
    const index = Math.min(LEVEL_ICONS.length - 1, Math.floor(percent(volume) / (100 / LEVEL_ICONS.length)));
    return LEVEL_ICONS[index];
}

export function micIcon({ muted }) {
    return muted ? MIC_MUTED_ICON : MIC_ICON;
}

// "  5%" … "150%": always four characters; the Bar font is monospace, so the island keeps its width.
export function percentText(volume) {
    return `${percent(volume)}%`.padStart(4);
}
