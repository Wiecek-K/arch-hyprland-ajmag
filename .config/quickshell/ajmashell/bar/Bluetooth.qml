// BT island — adapter and connection state only, like our Waybar "bluetooth" module
// (~/.config/waybar/Modules) without the connection count; connected devices show in the tooltip (D2, ticket 09).
// The only place on the Bar that shows a BT connection: the volume island has no BT mark (user, 2026-10-01).
// Left click opens the Orbita on the BT tab (ticket 12, wired in Bar.qml). No right click: it started
// blueman-applet + blueman-manager, the emergency fallback (D2), removed with the applets in ticket 23 (user, 2026-10-18).
// Own implementation, state from Quickshell.Bluetooth (BlueZ), logic in connectivity.mjs.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth as BT
import qs.singletons.theme
import "connectivity.mjs" as Logic

Island {
    id: root

    circle: true
    // a connection shows as the icon's accent colour only; the ring of 2026-10-01 went with the
    // shared island (user, 2026-10-05)

    readonly property BT.BluetoothAdapter adapter: BT.Bluetooth.defaultAdapter // qmllint disable unresolved-type
    readonly property list<BT.BluetoothDevice> connected: adapter?.devices.values.filter(device => device.connected) ?? [] // qmllint disable unresolved-type

    property bool orbitOpen: false // no tooltip over the open Orbita

    IconSlot {
        icons: Logic.BT_ICONS
        centred: true // alone in a round island
        text: Logic.btIcon({ enabled: root.adapter?.enabled ?? false, connected: root.connected.length })
        color: root.connected.length > 0 ? Theme.bar.connected : Theme.bar.text

        Behavior on color {
            ColorAnimation {
                duration: Theme.motion.fast
            }
        }
    }

    BarTooltip {
        target: root
        hovered: root.hovered && !root.orbitOpen
        text: Logic.btTooltip(root.connected.map(device => ({ name: device.name, batteryAvailable: device.batteryAvailable, battery: device.battery })))
    }
}
