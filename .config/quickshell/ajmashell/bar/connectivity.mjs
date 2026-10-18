// Pure logic of the Wi-Fi and BT islands (ticket 09): state icon and tooltip like our old Waybar
// "network" and "bluetooth" modules (waybar/Modules, dotfiles tag fallback-set-before-23).
// A JS module (not QML) so tools/test-bar-connectivity.mjs can test it with node.
// Own implementation; signal steps like serpantinum bar/modules/system/WifiWidget.qml (idea only):
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a

// Waybar network "format-icons", weakest → strongest
const SIGNAL_ICONS = ["\u{f092f}", "\u{f091f}", "\u{f0922}", "\u{f0925}", "\u{f0928}"];
const WIFI_OFF_ICON = "\u{f092e}"; // radio off; Waybar had no own icon for it
const DISCONNECTED_ICON = "\u{f0319}"; // Waybar "format-disconnected"
const ETHERNET_ICON = "\u{f0318}"; // Waybar "format-ethernet"
export const WIFI_ICONS = [...SIGNAL_ICONS, WIFI_OFF_ICON, DISCONNECTED_ICON, ETHERNET_ICON];

const BT_ON_ICON = "\u{f00af}"; // lines only; Waybar "format" U+F293 is a filled oval with the rune cut out (user, 2026-10-01)
const BT_OFF_ICON = "\u{f00b3}"; // Waybar "format-disabled"
const BT_CONNECTED_ICON = "\u{f00b1}"; // Waybar "format-connected", without {num_connections}: the island keeps its width
export const BT_ICONS = [BT_ON_ICON, BT_OFF_ICON, BT_CONNECTED_ICON];

function percent(value) {
    return Math.round((value ?? 0) * 100);
}

// enabled: Wi-Fi radio on; signal: 0–1 of the connected Wi-Fi network, null when none; wired: a cable connection is up.
export function wifiIcon({ enabled, signal = null, wired = false }) {
    if (enabled && signal !== null && signal !== undefined) {
        // Waybar: percent / (100 / 5), so 0-19, 20-39, … 80-100
        const index = Math.min(SIGNAL_ICONS.length - 1, Math.floor(percent(signal) / (100 / SIGNAL_ICONS.length)));
        return SIGNAL_ICONS[index];
    }
    if (wired)
        return ETHERNET_ICON;
    return enabled ? DISCONNECTED_ICON : WIFI_OFF_ICON;
}

// Waybar "tooltip-format-wifi": "{essid} {icon} {signalStrength}%" without the icon (it is on the island);
// "tooltip-format-ethernet": the interface name. Empty = no tooltip.
export function wifiTooltip({ name, signal, wiredName }) {
    if (name)
        return `${name} ${percent(signal)}%`;
    return wiredName ?? "";
}

// enabled: adapter powered; connected: number of connected devices.
export function btIcon({ enabled, connected }) {
    if (!enabled)
        return BT_OFF_ICON;
    return connected > 0 ? BT_CONNECTED_ICON : BT_ON_ICON;
}

// Waybar "tooltip-format-enumerate-connected": one device per line, battery when the device reports it.
export function btTooltip(devices) {
    return devices.map(device => device.batteryAvailable ? `${device.name} ${percent(device.battery)}%` : device.name).join("\n");
}
