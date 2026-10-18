// Wi-Fi island — state icon only (radio off, not connected, signal strength, cable), like our Waybar
// "network" module (~/.config/waybar/Modules); the network name shows in the tooltip (D2, ticket 09).
// Left click opens the Orbita on the Wi-Fi tab (ticket 12, wired in Bar.qml); right click opens
// nm-connection-editor, the emergency fallback (D2), started by Hyprland: a child of qs would die with
// every restart of ajmashell.service (ticket 23).
// Own implementation, state from Quickshell.Networking (NetworkManager), logic in connectivity.mjs.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import Quickshell.Networking
import "connectivity.mjs" as Logic
import "../launcher/launcher.mjs" as Launch

Island {
    id: root

    circle: true

    readonly property list<NetworkDevice> wifiDevices: Networking.devices.values.filter(device => device.type === DeviceType.Wifi)
    readonly property NetworkDevice wiredDevice: Networking.devices.values.find(device => device.type === DeviceType.Wired && device.connected) ?? null
    // a laptop has one Wi-Fi card; take the connected network of any of them
    readonly property WifiNetwork network: wifiDevices.map(device => device.networks.values.find(net => net.connected)).find(net => net) ?? null

    property bool orbitOpen: false // no tooltip over the open Orbita

    onRightClicked: Hyprland.dispatch(Launch.execRequest(["nm-connection-editor"], ""))

    IconSlot {
        icons: Logic.WIFI_ICONS
        centred: true // alone in a round island
        // The wedge is wide at the top, so its box-centred shape looks high; it also looked 1 px left
        // although its box sits exactly on the island's centre (user, 2026-10-01).
        opticalOffsetX: 1
        opticalOffsetY: 1
        text: Logic.wifiIcon({ enabled: Networking.wifiEnabled, signal: root.network?.signalStrength ?? null, wired: root.wiredDevice !== null })
    }

    BarTooltip {
        target: root
        hovered: root.hovered && !root.orbitOpen
        text: Logic.wifiTooltip({ name: root.network?.name, signal: root.network?.signalStrength, wiredName: root.wiredDevice?.name })
    }
}
