// Tray island — StatusNotifierItem icons of running apps, like our old Waybar "tray" module
// (waybar/Modules, dotfiles tag fallback-set-before-23: icon-size 20, spacing 4). Hidden while no app has an icon.
// Left click activates the app (or opens its menu if the app only has a menu), middle click is
// the secondary action, right click opens the app's menu, wheel goes to the app — like Waybar.
// Own implementation; click mapping after serpantinum src/quickshell/bar/modules/TrayWidget.qml (idea only):
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// The menu is our own TrayMenu (Theme colours), one per tray island.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.singletons.theme
import "tray.mjs" as Logic

Island {
    id: root

    visible: SystemTray.items.values.length > 0
    spacing: Theme.bar.traySpacing

    TrayMenu {
        id: trayMenu
    }

    Repeater {
        id: entries
        model: SystemTray.items

        // Full island height, so the tooltip sits under the island like on the other islands.
        Item {
            id: entry
            required property SystemTrayItem modelData

            implicitWidth: Theme.bar.trayIconSize
            implicitHeight: Theme.bar.islandHeight

            // app quit while its menu was open
            Component.onDestruction: {
                if (trayMenu.source === entry)
                    trayMenu.close();
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: Theme.bar.trayIconSize
                source: entry.modelData.icon
            }

            // Takes the clicks before the island's own TapHandler; the island has no click action.
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: event => {
                    const item = entry.modelData;
                    if (event.button === Qt.MiddleButton)
                        item.secondaryActivate();
                    else if (event.button === Qt.RightButton || item.onlyMenu)
                        item.hasMenu ? trayMenu.toggle(entry, item.menu, item.id) : item.activate(); // qmllint disable unresolved-type
                    else
                        item.activate();
                }
                onWheel: event => entry.modelData.scroll(event.angleDelta.y, false)
            }

            BarTooltip {
                target: entry
                hovered: mouse.containsMouse && !trayMenu.visible
                text: entry.modelData.tooltipTitle || entry.modelData.title
            }
        }
    }
}
