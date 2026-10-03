// TrayMenu — an app's tray menu (DBusMenu) drawn by Ajmashell in Theme colours, under its tray icon.
// Own menu instead of the Qt platform menu (QsMenuAnchor): that one needs QApplication mode and has a
// light Fusion look (user, 2026-10-01, ticket 09). Submenus open in place with a back row, like
// DankMaterialShell Modules/DankBar/Widgets/SystemTrayBar.qml (idea only, own implementation):
// https://github.com/AvengeMedia/DankMaterialShell@9dc5b2c5af7d18b7231f425fe0d8fa7243233109
// Closes on a click outside (HyprlandFocusGrab), on Esc and after an entry is chosen.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.singletons.theme
import "tray.mjs" as Logic

PopupWindow {
    id: root

    property Item source: null // tray icon the menu hangs under
    property var menu: null // QsMenuHandle of the app's root menu
    property list<QtObject> path: [] // submenu entries opened so far, at most maxDepth
    readonly property int maxDepth: 2
    readonly property var current: path.length > 0 ? path[path.length - 1] : menu

    function toggle(item: Item, handle: var): void {
        if (visible && source === item) {
            close();
            return;
        }
        source = item;
        menu = handle;
        path = [];
        visible = true;
    }

    function close(): void {
        visible = false;
        path = [];
        menu = null;
    }

    function choose(entry: var): void {
        if (!entry.enabled)
            return;
        if (entry.hasChildren) {
            if (path.length < maxDepth)
                path = [...path, entry];
            return;
        }
        entry.triggered();
        close();
    }

    visible: false
    anchor.item: source
    anchor.rect.x: 0
    anchor.rect.y: 0
    anchor.rect.width: source?.width ?? 0
    anchor.rect.height: (source?.height ?? 0) + Theme.bar.tooltip.gap
    // qmltypes give these as Edges::Flags, which qmllint cannot resolve
    anchor.edges: Edges.Bottom // qmllint disable missing-type
    anchor.gravity: Edges.Bottom // qmllint disable missing-type

    implicitWidth: Math.ceil(content.implicitWidth) + 2 * Theme.bar.menu.padding
    implicitHeight: Math.ceil(content.implicitHeight) + 2 * Theme.bar.menu.padding
    color: Theme.transparent // only the rounded box below is drawn

    // The grab refuses a window that is not mapped yet, so arm it after the popup shows.
    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => grab.active = visible);
        else
            grab.active = false;
    }

    HyprlandFocusGrab {
        id: grab
        windows: [root]
        onCleared: root.close()
    }

    // One opener per level, all open at once: when a menu loses its last opener, Quickshell drops
    // its entries, and the submenu entry we stand in would go with them.
    QsMenuOpener {
        id: level0
        menu: root.menu // qmllint disable unresolved-type
    }

    QsMenuOpener {
        id: level1
        menu: root.path[0] ?? null // qmllint disable unresolved-type
    }

    QsMenuOpener {
        id: level2
        menu: root.path[1] ?? null // qmllint disable unresolved-type
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.lg
        color: Theme.bar.menu.background

        focus: true
        Keys.onEscapePressed: root.path.length > 0 ? root.path = root.path.slice(0, -1) : root.close()

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Theme.bar.menu.padding
            spacing: 0

            MenuRow {
                visible: root.path.length > 0
                mark: Logic.BACK_ICON
                label: Logic.menuLabel(root.current?.text)
                onChosen: root.path = root.path.slice(0, -1)
            }

            Repeater {
                model: [level0, level1, level2][root.path.length].children // qmllint disable unresolved-type

                MenuRow {
                    required property var modelData

                    separator: modelData.isSeparator
                    enabled: modelData.enabled
                    mark: Logic.checkMark(modelData.buttonType, modelData.checkState)
                    icon: modelData.icon
                    label: Logic.menuLabel(modelData.text)
                    submenu: modelData.hasChildren && root.path.length < root.maxDepth
                    onChosen: root.choose(modelData)
                }
            }
        }
    }

    component MenuRow: Item {
        id: row

        property bool separator: false
        property string mark
        property string icon
        property string label
        property bool submenu: false
        signal chosen

        Layout.fillWidth: true
        implicitWidth: separator ? 0 : Math.max(Theme.bar.menu.minWidth, Math.ceil(line.implicitWidth) + 2 * Theme.bar.menu.rowPadding)
        implicitHeight: separator ? Theme.bar.menu.separatorGap : Theme.bar.menu.rowHeight
        opacity: enabled ? 1 : Theme.bar.menu.disabledOpacity

        Rectangle {
            visible: row.separator
            anchors.centerIn: parent
            width: parent.width - 2 * Theme.bar.menu.rowPadding
            height: 1
            color: Theme.bar.menu.separator
        }

        Rectangle {
            visible: !row.separator
            anchors.fill: parent
            radius: Theme.radius.sm
            color: hover.hovered && row.enabled ? Theme.bar.menu.hover : Theme.transparent
        }

        RowLayout {
            id: line
            visible: !row.separator
            anchors.fill: parent
            anchors.leftMargin: Theme.bar.menu.rowPadding
            anchors.rightMargin: Theme.bar.menu.rowPadding
            spacing: Theme.spacing.md

            MenuText {
                visible: row.mark !== ""
                text: row.mark
            }

            IconImage {
                visible: row.icon !== ""
                implicitSize: Theme.bar.menu.iconSize
                source: row.icon
            }

            MenuText {
                Layout.fillWidth: true
                text: row.label
            }

            MenuText {
                visible: row.submenu
                text: Logic.SUBMENU_ICON
            }
        }

        HoverHandler {
            id: hover
            enabled: !row.separator
        }

        TapHandler {
            enabled: !row.separator && row.enabled
            onTapped: row.chosen()
        }
    }

    component MenuText: Text {
        font.family: Theme.font.family
        font.pixelSize: Theme.font.sizeSmall
        font.weight: Theme.font.weight
        color: Theme.bar.menu.text
        elide: Text.ElideRight
    }
}
