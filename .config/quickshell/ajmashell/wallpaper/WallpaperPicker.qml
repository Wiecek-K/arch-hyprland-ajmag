// Wallpaper carousel (ticket 19, B11 #04): SUPER+W → qs -c ajmashell ipc call wallpaper toggle (keybinds.lua).
// Horizontal strip of sheared thumbnails with an "All" tab and 7 colour filters; Enter or a click on the current
// card runs ~/.config/hypr/scripts/wpapply.sh (matugen + hyprpaper, the same as the rofi picker).
// Adapted from serpantinum src/quickshell/wallpaper/WallpaperPicker.qml:
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// Copyright (C) 2026 Illia Miroshnichenko — AGPL-3.0-or-later
// Changes: kept the card look (current card 1.5× wide, neighbours shrinking with distance, sheared cards with
// a counter-sheared image, wheel accumulator) and the bucket filters; dropped History, Video, Search, monitor
// selector, FolderListModel proxies and the Config/I18n/Scaler layers; colours and sizes from Theme.
// Own: a Repeater laid out from one animated position (carousel.mjs layout) instead of a ListView whose
// highlight animation and the cards' resize ran on different curves and jolted at the end (user, 2026-10-01);
// one cubic-bezier curve in Theme.wallpaper.curve; rounded cards (sharp corners clash with the soft rest of the
// system; sheared style chosen out of four trials) that tuck slightly under each other; antialiased edges;
// no slide-in on open; own window: a layer-shell overlay on the focused monitor, created once and hidden when
// closed (rebuilding it on every open stalled the first frames, user 2026-10-01).
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.singletons.theme
import "carousel.mjs" as Logic

Scope {
    id: root

    property bool open: false
    property var items: [] // index.json items (indexer.py)
    property string currentPath: "" // wallpaper set now (~/.config/hypr/current_wallpaper)

    readonly property string home: Quickshell.env("HOME")
    readonly property string cacheDir: home + "/.cache/ajmashell/wallpapers"

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            root.open = !root.open;
        }
    }

    // know the current wallpaper before the first open, so the carousel starts on it
    Component.onCompleted: currentWallpaper.running = true

    onOpenChanged: {
        if (!open)
            return;
        currentWallpaper.running = true;
        indexer.running = true; // cheap when nothing changed: stats files, reuses the cache
    }

    function setItems(json: string): void {
        try {
            const next = JSON.parse(json).items || [];
            if (JSON.stringify(next) !== JSON.stringify(items))
                items = next;
        } catch (e) {
            console.warn("WallpaperPicker: bad index:", e);
        }
    }

    function apply(path: string): void {
        Quickshell.execDetached([home + "/.config/hypr/scripts/wpapply.sh", path]);
        currentPath = path;
        open = false;
    }

    // The cached index, so the carousel shows at once; the indexer refreshes it in the background
    FileView {
        id: indexFile
        path: root.cacheDir + "/index.json"
        onLoaded: root.setItems(text())
    }

    Process {
        id: indexer
        command: ["python3", Quickshell.shellDir + "/wallpaper/indexer.py"]
        stdout: StdioCollector {
            onStreamFinished: root.setItems(text)
        }
    }

    Process {
        id: currentWallpaper
        command: ["readlink", "-f", root.home + "/.config/hypr/current_wallpaper"]
        stdout: StdioCollector {
            onStreamFinished: root.currentPath = text.trim()
        }
    }

    // Created once at startup and only hidden when closed: rebuilding the window on every open (new scene graph,
    // shaders, textures, 112 cards) stalled the first frames for ~0.5 s (user, 2026-10-01).
    LazyLoader {
        active: true

        // qmltypes mark PanelWindow uncreatable; Quickshell substitutes the Wayland implementation at runtime
        PanelWindow { // qmllint disable uncreatable-type
            id: win

            visible: root.open

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: Theme.transparent // the backdrop below fades in instead of appearing at once
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "ajmashell-wallpaper"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            property string filter: "All"
            readonly property var list: Logic.visibleItems(root.items, filter)
            // sizes from the monitor, not the window: the hidden window has no size yet, and with zero sizes every
            // card counted as on screen and loaded its thumbnail (421 MB RSS at startup)
            readonly property real viewWidth: screen?.width ?? 0
            readonly property real viewHeight: screen?.height ?? 0
            readonly property real itemWidth: viewWidth * Theme.wallpaper.itemWidthRatio
            readonly property real itemHeight: viewHeight * Theme.wallpaper.itemHeightRatio
            // serpantinum selectedCenterOffset: keeps the sheared current card visually centred
            readonly property real centerOffset: Logic.SKEW * itemHeight / 2

            // One animated number drives the whole strip: card positions, sizes and dimming are pure functions
            // of `pos` (carousel.mjs layout), so they always move together and end together.
            property var model: []
            property int current: 0
            property real pos: 0
            Behavior on pos {
                enabled: win.settled
                NumberAnimation {
                    duration: Theme.wallpaper.move
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.wallpaper.curve
                }
            }
            onCurrentChanged: pos = current
            readonly property var strip: Logic.layout(model.length, pos, itemWidth, itemHeight, Theme.wallpaper.overlap)

            function step(n: int): void {
                current = Math.max(0, Math.min(model.length - 1, current + n));
            }

            // show `list`, centred on `path` (or on the first card), without animation; the view fades in
            // (user, 2026-10-01: no slide across the list on open)
            property bool settled: false
            function sync(path: string): void {
                settled = false;
                model = list;
                current = Logic.indexOfPath(list, path);
                pos = current;
                Qt.callLater(() => win.settled = win.visible); // hidden: stay faded out until the next open
            }
            // new list (filter, refreshed index): stay on the same wallpaper
            onListChanged: sync(current < model.length ? model[current].path : root.currentPath)
            Component.onCompleted: sync(root.currentPath)
            // reopened: back to the current wallpaper and the "All" filter, faded in again
            onVisibleChanged: {
                if (!visible) {
                    settled = false; // ready to fade in on the next open
                    return;
                }
                filter = "All";
                sync(root.currentPath);
            }

            Connections {
                target: root
                function onCurrentPathChanged() {
                    win.sync(root.currentPath);
                }
            }

            // dimmed background, faded in with the window (user, 2026-10-01); reset while hidden like the cards
            Rectangle {
                anchors.fill: parent
                color: Theme.wallpaper.backdrop
                opacity: win.settled ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.wallpaper.backdropAppear
                    }
                }
            }

            // click on the backdrop closes
            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }

            // Filter row: All + 7 colours, Theme.wallpaper.gap above the current card
            Rectangle {
                id: filterBar
                anchors.bottom: stage.verticalCenter
                anchors.bottomMargin: win.itemHeight / 2 + Theme.wallpaper.gap
                anchors.horizontalCenter: parent.horizontalCenter
                height: Theme.wallpaper.filterHeight
                width: filterRow.width + 2 * Theme.spacing.md
                radius: height / 2
                color: Theme.wallpaper.panel

                Row {
                    id: filterRow
                    anchors.centerIn: parent
                    spacing: Theme.spacing.sm

                    Repeater {
                        model: Logic.FILTERS

                        Rectangle {
                            id: pill
                            required property string modelData
                            readonly property bool selected: win.filter === modelData
                            readonly property bool empty: modelData !== "All" && !root.items.some(i => i.bucket === modelData)

                            height: Theme.wallpaper.filterHeight - 2 * Theme.spacing.sm
                            width: modelData === "All" ? allLabel.implicitWidth + 2 * Theme.spacing.lg : height
                            radius: height / 2
                            color: selected ? Theme.wallpaper.active : Theme.transparent
                            opacity: empty ? 0.3 : 1
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.motion.fast
                                }
                            }

                            Text {
                                id: allLabel
                                visible: pill.modelData === "All"
                                anchors.centerIn: parent
                                text: "All"
                                color: pill.selected ? Theme.wallpaper.activeText : Theme.wallpaper.text
                                font.family: Theme.font.family
                                font.weight: Theme.font.weight
                                font.pixelSize: Theme.font.size
                            }

                            Rectangle {
                                visible: pill.modelData !== "All"
                                anchors.centerIn: parent
                                width: Theme.wallpaper.filterDot
                                height: width
                                radius: width / 2
                                color: Theme.wallpaper.buckets[pill.modelData] ?? Theme.transparent
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !pill.empty
                                onClicked: win.filter = pill.modelData
                            }
                        }
                    }
                }
            }

            Item {
                id: stage
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: win.itemHeight + 80
                focus: true
                opacity: win.settled ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.wallpaper.appear
                    }
                }

                Keys.onEscapePressed: root.open = false
                Keys.onReturnPressed: if (win.current < win.model.length) root.apply(win.model[win.current].path)
                Keys.onEnterPressed: if (win.current < win.model.length) root.apply(win.model[win.current].path)
                Keys.onLeftPressed: win.step(-1)
                Keys.onRightPressed: win.step(1)
                Keys.onTabPressed: win.filter = Logic.stepFilter(win.filter, 1, root.items)
                Keys.onBacktabPressed: win.filter = Logic.stepFilter(win.filter, -1, root.items)

                // wheel: one card per notch-sized step (serpantinum accumulator, throttle left out)
                property real wheelAccum: 0
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        const d = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y;
                        stage.wheelAccum += d;
                        if (Math.abs(stage.wheelAccum) >= 120) {
                            win.step(stage.wheelAccum > 0 ? -1 : 1);
                            stage.wheelAccum = 0;
                        }
                    }
                }

                Repeater {
                    model: win.model

                    Item {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property real offset: index - win.pos
                        readonly property var g: win.strip.cards[index] ?? ({ x: 0, width: 0, height: 0, cell: 0 })
                        readonly property bool current: index === win.current

                        // cell in stage coordinates: the strip's centre point sits in the middle of the view
                        x: g.x - win.strip.centre + win.viewWidth / 2 + win.centerOffset
                        width: g.cell
                        height: stage.height
                        z: 100 - Math.abs(offset)
                        // only cards near the screen get a texture and a thumbnail
                        visible: x + width + win.itemWidth > 0 && x - win.itemWidth < win.viewWidth

                        Item {
                            id: shape
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: -(Logic.SKEW * height) / 2 // serpantinum: centre the sheared card
                            width: card.g.width
                            height: card.g.height

                            // The shear makes the slanted edges jagged (segments, user 2026-10-01): render the card
                            // into a texture and draw it with antialiased, smoothly sampled edges.
                            layer.enabled: card.visible
                            layer.smooth: true
                            antialiasing: true

                            transform: Matrix4x4 {
                                matrix: Qt.matrix4x4(1, Logic.SKEW, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }

                            ClippingRectangle {
                                anchors.fill: parent
                                radius: Theme.wallpaper.cardRadius
                                color: Theme.wallpaper.card
                                border.width: card.current ? Theme.wallpaper.border : 0
                                // the card's own primary (index.json), the accent the system gets with this wallpaper,
                                // not the current system colour (user, 2026-10-01)
                                border.color: card.modelData.primary || Theme.wallpaper.active

                                Image {
                                    // counter-sheared, so the picture itself stays upright inside the sheared card
                                    x: Logic.SKEW * shape.height
                                    width: parent.width - Logic.SKEW * shape.height
                                    height: parent.height
                                    source: card.visible ? "file://" + card.modelData.thumb : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.height: 540 // thumbnails are 540 px high (indexer.py)
                                    transform: Matrix4x4 {
                                        matrix: Qt.matrix4x4(1, -Logic.SKEW, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                                    }
                                }

                                // dim the cards away from the centre a little, so the current one leads
                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.colors.scrim
                                    opacity: Math.min(0.45, Math.abs(card.offset) * 0.15 + Math.max(0, Math.abs(card.offset) - 1) * 0.06)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: card.current ? root.apply(card.modelData.path) : win.current = card.index
                            }
                        }
                    }
                }
            }

            // File name only (user, 2026-10-01: no key hints), in the Bar's font family, SemiBold; Theme.wallpaper.gap below the current card
            Rectangle {
                anchors.top: stage.verticalCenter
                anchors.topMargin: win.itemHeight / 2 + Theme.wallpaper.gap
                anchors.horizontalCenter: parent.horizontalCenter
                height: Theme.wallpaper.filterHeight
                width: fileName.implicitWidth + 2 * Theme.spacing.lg + Theme.spacing.md
                radius: height / 2
                color: Theme.wallpaper.panel

                Text {
                    id: fileName
                    anchors.centerIn: parent
                    text: win.model.length ? win.model[win.current]?.fileName ?? "" : "brak tapet"
                    color: Theme.wallpaper.text
                    font.family: Theme.font.family
                    font.weight: Font.DemiBold // SemiBold, a bit lighter than the Bar's Bold (user, 2026-10-01)
                    font.pixelSize: Theme.font.size
                }
            }
        }
    }
}
