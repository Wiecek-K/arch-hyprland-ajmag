// Launcher (ticket 11, B09 §1): SUPER+D → ~/.config/hypr/scripts/launcher.sh → qs -c ajmashell ipc call launcher toggle.
// Layout of the rofi it replaces (~/.config/rofi/config.rasi): wallpaper pane with the search field and the mode
// buttons | list of 8 rows. Modes: Applications (drun) and Windows (focus the window, also on another workspace
// and monitor); Tab switches. Text starting with "=" shows a qalc result instead of the list; Enter copies it.
// Search order adapted from serpantinum src/quickshell/launcher/Launcher.qml (see launcher.mjs):
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// Copyright (C) 2026 Illia Miroshnichenko — AGPL-3.0-or-later
// Changes: only the matching kept (no file search, ">" commands, widgets, emoji, app_rank.py, intro animation,
// Config/I18n layers); look and sizes of our rofi theme from Theme.launcher; usage counts in rofi's history
// format (ours, the rofi history was copied once on 2026-10-02 and is not read any more); apps started by Hyprland, not by qs (launcher.mjs execRequest).
// Calculator after end-4/dots-hyprland ii/services/LauncherSearch.qml (qalc in a Process; pattern only), with our guard:
// https://github.com/end-4/dots-hyprland/blob/547836f1b01a45445cfbbcd92b206d1b5ceee4d9/dots/.config/quickshell/ii/services/LauncherSearch.qml
// Own: window list (B09 §1.5), the window created once and only hidden (as the wallpaper carousel), the last 5
// copied results shown after a bare "=" (calc-history.json).
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.singletons.theme
import "launcher.mjs" as Logic
import "../orbit" // OrbitBackdrop behind the list in the fancy look (ticket 13)
import qs.singletons.look // F2: basic ↔ fancy look (ticket 13)

Scope {
    id: root

    property bool open: false
    property string mode: "apps" // Logic.MODES
    property string wallpaper: "" // resolved ~/.config/hypr/current_wallpaper
    property var usage: ({}) // { desktop id: launches }
    property var calcHistory: [] // [{ expr, value }], newest first; shown after a bare "="

    readonly property string home: Quickshell.env("HOME")

    // plain objects for launcher.mjs; the entry / toplevel rides along for launching and focusing
    readonly property var apps: DesktopEntries.applications.values.map(e => ({
                id: e.id,
                name: e.name,
                genericName: e.genericName,
                comment: e.comment,
                keywords: Array.from(e.keywords),
                icon: e.icon,
                entry: e
            }))
    readonly property var windows: Hyprland.toplevels.values.map(t => {
        const ipc = t.lastIpcObject;
        const appId = ipc.class || t.wayland?.appId || "";
        return {
            address: t.address.startsWith("0x") ? t.address : "0x" + t.address,
            title: t.title || appId,
            appId: appId,
            workspace: ipc.workspace?.name ?? "",
            focusHistory: ipc.focusHistoryID ?? -1,
            icon: DesktopEntries.heuristicLookup(appId)?.icon ?? appId
        };
    })

    IpcHandler {
        target: "launcher"

        // Applications; closes when already open
        function toggle(): void {
            root.show("apps");
        }

        function windows(): void {
            root.show("windows");
        }
    }

    function show(m: string): void {
        if (open && mode === m) {
            open = false;
            return;
        }
        mode = m;
        open = true;
    }

    onOpenChanged: {
        if (!open)
            return;
        wallpaperLink.running = true;
        Hyprland.refreshToplevels(); // focus order and workspaces live in lastIpcObject
    }

    function activate(item: var): void {
        if (calc.active) {
            if (calc.ready)
                copyResult(calc.input, calc.value);
            else if (!calc.input && item)
                copyResult(item.expr, item.value); // a history row
            return; // an invalid or unfinished expression keeps the launcher open
        }
        if (!item)
            return;
        open = false; // first give the keyboard back, then Hyprland focuses the new or chosen window
        if (mode === "windows") {
            Hyprland.dispatch(Logic.focusRequest(item.address));
            return;
        }
        const e = item.entry;
        const command = Array.from(e.command);
        Hyprland.dispatch(Logic.execRequest(e.runInTerminal ? Logic.terminalCommand(command) : command, e.workingDirectory));
        usage = Logic.addLaunch(usage, e.id);
        usageFile.setText(Logic.formatUsage(usage));
    }

    function copyResult(expr: string, value: string): void {
        Quickshell.execDetached(["wl-copy", "--", value]);
        open = false;
        calcHistory = Logic.addCalc(calcHistory, expr, value);
        calcHistoryFile.setText(Logic.formatCalcHistory(calcHistory));
    }

    FileView {
        id: calcHistoryFile
        path: root.home + "/.local/state/ajmashell/calc-history.json"
        onLoaded: root.calcHistory = Logic.parseCalcHistory(text())
    }

    // Launch counts, most used first in the list (like rofi's history); a fresh system starts empty
    FileView {
        id: usageFile
        path: root.home + "/.local/state/ajmashell/launcher-usage"
        onLoaded: root.usage = Logic.parseUsage(text())
    }

    Process {
        id: wallpaperLink
        command: ["readlink", "-f", root.home + "/.config/hypr/current_wallpaper"]
        stdout: StdioCollector {
            onStreamFinished: root.wallpaper = text.trim()
        }
    }

    // Calculator: qalc runs after a pause in typing; one run at a time, the newest expression wins.
    QtObject {
        id: calc

        property bool active: false
        property string input: "" // expression typed now
        property string value: "" // qalc result for `doneFor`
        property string doneFor: "" // expression the value or error belongs to
        property string error: "" // shown instead of a result
        readonly property bool ready: value !== "" && doneFor === input && !delay.running && !qalc.running

        function request(expr: string): void {
            input = expr;
            const check = Logic.checkExpression(expr);
            if (!check.ok) {
                delay.stop();
                value = "";
                doneFor = expr;
                error = check.reason === "empty" ? "" : check.reason.startsWith("unknown") ? "unsupported name: " + check.reason.slice(9) : "unsupported symbol";
                return;
            }
            delay.restart();
        }

        function run(): void {
            if (qalc.running || !Logic.checkExpression(input).ok)
                return; // a running qalc calls run() again when it ends
            qalc.expr = input;
            qalc.started = false;
            qalc.command = Logic.calcCommand(input);
            qalc.running = true;
        }

        function finished(out: string, exitCode: int): void {
            if (qalc.expr !== input) { // typed on meanwhile
                run();
                return;
            }
            const result = Logic.calcResult(out, exitCode);
            value = result.value;
            doneFor = input;
            error = result.ok ? "" : "cannot calculate";
        }

        function missing(): void {
            value = "";
            doneFor = input;
            error = "qalc not found (package libqalculate)";
        }
    }

    Timer {
        id: delay
        interval: Theme.launcher.calcDelay
        onTriggered: calc.run()
    }

    Process {
        id: qalc
        property string expr: ""
        property string out: ""
        property int exitCode: 0
        property int parts: 0 // stdout end and exit both arrive, in either order
        property bool started: false

        function part(): void {
            if (++parts === 2)
                calc.finished(out, exitCode);
        }

        onStarted: {
            parts = 0;
            started = true;
        }
        // a binary that cannot start emits neither started nor exited, only running = false
        onRunningChanged: if (!running && !started) calc.missing()
        stdout: StdioCollector {
            onStreamFinished: {
                qalc.out = text;
                qalc.part();
            }
        }
        onExited: code => { // qmllint disable signal-handler-parameters
            qalc.exitCode = code;
            qalc.part();
        }
    }

    // Created once at startup and only hidden when closed (as the wallpaper carousel: no stall on open).
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
            color: Theme.transparent // only the launcher box is drawn; a click beside it closes
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "ajmashell-launcher"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            readonly property var query: Logic.parseQuery(search.text)
            readonly property bool calcMode: query.kind === "calc"
            readonly property bool showHistory: calcMode && !query.expr && root.calcHistory.length > 0
            // rows the arrows and Enter work on: apps, windows or, after a bare "=", the calculator history
            // calc mode: history rows (after a bare "=") then the calculator keys
            readonly property var items: calcMode ? (showHistory ? root.calcHistory : []).concat(Logic.CALC_KEYS) : root.mode === "windows" ? Logic.filterWindows(root.windows, query.query) : Logic.filterApps(root.apps, query.query, root.usage)
            property int current: 0
            readonly property int rowHeight: Theme.launcher.iconSize + 2 * Theme.launcher.rowPadding

            // nothing selected (-1) while typing an expression: Enter copies the result until an arrow picks a key
            onItemsChanged: current = items.length > 0 && items[0].insert !== undefined ? -1 : 0

            // Arrows: the list (up/down) or, in calc mode, history rows and the keys grid; false = not used
            function move(key: string): bool {
                if (!calcMode) {
                    if (key === "left" || key === "right")
                        return false;
                    current = Logic.step(current, items.length, key === "up" ? -1 : 1);
                    return true;
                }
                const next = Logic.calcMove(current, showHistory ? root.calcHistory.length : 0, Logic.CALC_KEYS.length, Theme.launcher.calcKeyColumns, key);
                if (next === null)
                    return false;
                current = next;
                return true;
            }

            // Enter or click: a calculator key goes into the field, anything else to root.activate
            function choose(item: var): void {
                if (item && item.insert !== undefined) {
                    const next = Logic.insertKey(search.text, search.cursorPosition, item);
                    search.text = next.text;
                    search.cursorPosition = next.cursor;
                    current = -1; // Enter copies the result again
                    return;
                }
                root.activate(item);
            }
            onCurrentChanged: if (!calcMode && current >= 0) list.positionViewAtIndex(current, ListView.Contain)
            onQueryChanged: {
                // query.kind, not calcMode: in this handler calcMode still holds the old value
                calc.active = query.kind === "calc";
                if (calc.active)
                    calc.request(query.expr);
                if (calc.active && query.expr)
                    current = -1; // typing drops a key picked with the arrows (items stay the same array)
            }
            onVisibleChanged: {
                if (!visible)
                    return;
                search.text = "";
                current = 0;
                search.forceActiveFocus();
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }

            ClippingRectangle {
                id: box
                anchors.centerIn: parent
                width: Theme.launcher.width
                height: Theme.launcher.rows * win.rowHeight + (Theme.launcher.rows - 1) * Theme.launcher.rowSpacing + 2 * Theme.launcher.padding
                radius: Theme.launcher.radius
                color: Theme.launcher.background
                border.width: Theme.launcher.borderWidth
                border.color: Theme.launcher.border

                MouseArea {
                    anchors.fill: parent // clicks on the box do not reach the closing area below
                }

                // --- wallpaper pane: search field on top, mode buttons at the bottom ---
                Item {
                    id: pane
                    width: parent.width / 2
                    height: parent.height

                    Image {
                        anchors.fill: parent
                        source: root.wallpaper ? "file://" + root.wallpaper : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.height: box.height // decode the large wallpaper at the pane's size
                    }

                    Rectangle {
                        id: field
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.launcher.padding
                        height: search.implicitHeight + 2 * Theme.launcher.fieldPadding
                        radius: Theme.launcher.fieldRadius
                        color: Theme.launcher.field

                        Text {
                            id: searchIcon
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.launcher.fieldPadding
                            anchors.verticalCenter: parent.verticalCenter
                            text: "" // nf-fa-search, as rofi's prompt
                            color: Theme.launcher.text
                            font.family: Theme.font.family
                            font.weight: Theme.launcher.fontWeight
                            font.pixelSize: Theme.launcher.fontSize
                        }

                        TextInput {
                            id: search
                            anchors.left: searchIcon.right
                            anchors.leftMargin: Theme.launcher.fieldSpacing
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.launcher.fieldPadding
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.launcher.text
                            selectionColor: Theme.launcher.active
                            selectedTextColor: Theme.launcher.activeText
                            font.family: Theme.font.family
                            font.weight: Theme.launcher.fontWeight
                            font.pixelSize: Theme.launcher.fontSize
                            clip: true
                            focus: true

                            Keys.onEscapePressed: root.open = false
                            // F2 switches the look: basic ↔ fancy (ticket 13)
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_F2) {
                                    Look.cycle();
                                    event.accepted = true;
                                }
                            }
                            Keys.onReturnPressed: win.choose(win.current >= 0 ? win.items[win.current] : null) // -1: nothing selected
                            Keys.onEnterPressed: win.choose(win.current >= 0 ? win.items[win.current] : null) // -1: nothing selected
                            Keys.onUpPressed: win.move("up")
                            Keys.onDownPressed: win.move("down")
                            Keys.onLeftPressed: event => event.accepted = win.move("left") // false: the text cursor moves
                            Keys.onRightPressed: event => event.accepted = win.move("right")
                            Keys.onTabPressed: root.mode = Logic.nextMode(root.mode)
                            Keys.onBacktabPressed: root.mode = Logic.nextMode(root.mode)

                            Text {
                                visible: !search.text
                                text: "Search"
                                color: Theme.launcher.placeholder
                                font: search.font
                            }
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.launcher.padding
                        spacing: Theme.launcher.modeSpacing

                        Repeater {
                            model: Logic.MODES

                            Rectangle {
                                id: modeButton
                                required property string modelData
                                readonly property bool selected: root.mode === modelData

                                width: modeLabel.implicitWidth + 2 * Theme.launcher.fieldPadding
                                height: modeLabel.implicitHeight + 2 * Theme.launcher.fieldPadding
                                radius: Theme.launcher.fieldRadius
                                color: selected ? Theme.launcher.active : Theme.launcher.field

                                Text {
                                    id: modeLabel
                                    anchors.centerIn: parent
                                    text: modeButton.modelData === "apps" ? "Applications" : "Windows"
                                    color: modeButton.selected ? Theme.launcher.activeText : Theme.launcher.modeText // inactive: dimmed like the placeholder
                                    font: search.font
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.mode = modeButton.modelData
                                }
                            }
                        }
                    }
                }

                // fancy look (ticket 13, user 2026-10-06): the Orbita's lens flare behind the list; turns
                // like the orbit while open
                OrbitBackdrop {
                    id: listBackdrop
                    visible: Theme.orbit.looks[Look.mode].flare
                    x: pane.width
                    width: box.width - pane.width
                    height: box.height
                    radius: 0 // the box clips its own corners

                    FrameAnimation {
                        running: win.visible && listBackdrop.visible
                        onTriggered: listBackdrop.angle = (listBackdrop.angle + 2 * Math.PI * frameTime * 1000 / Theme.orbit.period) % (2 * Math.PI)
                    }
                }

                // --- list pane ---
                ListView {
                    id: list
                    x: pane.width + Theme.launcher.padding
                    y: Theme.launcher.padding
                    width: box.width - pane.width - 2 * Theme.launcher.padding
                    height: box.height - 2 * Theme.launcher.padding
                    visible: !win.calcMode
                    clip: true
                    spacing: Theme.launcher.rowSpacing
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.calcMode ? [] : win.items // calc mode: items are history rows, not apps — no delegates for them

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool selected: index === win.current

                        width: ListView.view.width
                        height: win.rowHeight
                        radius: Theme.launcher.fieldRadius
                        color: selected ? Theme.launcher.active : Theme.transparent

                        IconImage {
                            id: icon
                            x: Theme.launcher.rowPadding
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: Theme.launcher.iconSize
                            source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                            asynchronous: true
                        }

                        Text {
                            anchors.left: icon.right
                            anchors.leftMargin: Theme.launcher.iconGap
                            anchors.right: workspace.left
                            anchors.rightMargin: Theme.launcher.rowPadding
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.mode === "windows" ? row.modelData.title : row.modelData.name
                            elide: Text.ElideRight
                            color: row.selected ? Theme.launcher.activeText : Theme.launcher.text
                            font: search.font
                        }

                        // windows: the workspace, as rofi's window mode showed it
                        Text {
                            id: workspace
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.launcher.rowPadding
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.mode === "windows" ? row.modelData.workspace : ""
                            color: row.selected ? Theme.launcher.activeText : Theme.launcher.subtext
                            font: search.font
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onPositionChanged: win.current = row.index // a moved pointer selects, a resting one does not
                            onClicked: win.choose(row.modelData)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: win.items.length === 0
                        text: root.mode === "windows" ? "No windows" : "No applications"
                        color: Theme.launcher.subtext
                        font: search.font
                    }
                }

                // --- calculator history, after a bare "=" ---
                Column {
                    x: list.x
                    y: list.y
                    width: list.width
                    spacing: Theme.launcher.rowSpacing
                    visible: win.showHistory

                    Repeater {
                        model: win.showHistory ? root.calcHistory : []

                        Rectangle {
                            id: historyRow
                            required property var modelData
                            required property int index
                            readonly property bool selected: index === win.current

                            width: parent.width
                            height: win.rowHeight
                            radius: Theme.launcher.fieldRadius
                            color: selected ? Theme.launcher.active : Theme.transparent

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: Theme.launcher.rowPadding
                                anchors.verticalCenter: parent.verticalCenter
                                text: historyRow.modelData.expr + " = " + historyRow.modelData.value
                                elide: Text.ElideMiddle
                                color: historyRow.selected ? Theme.launcher.activeText : Theme.launcher.text
                                font: search.font
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onPositionChanged: win.current = historyRow.index
                                onClicked: win.choose(historyRow.modelData)
                            }
                        }
                    }
                }

                // --- calculator keys, at the bottom of the list pane ---
                Grid {
                    id: calcKeys
                    x: list.x
                    y: list.y + list.height - height
                    width: list.width
                    columns: Theme.launcher.calcKeyColumns
                    spacing: Theme.launcher.rowSpacing
                    visible: win.calcMode

                    Repeater {
                        model: Logic.CALC_KEYS

                        Rectangle {
                            id: calcKey
                            required property var modelData
                            required property int index
                            readonly property int itemIndex: index + win.items.length - Logic.CALC_KEYS.length
                            readonly property bool selected: itemIndex === win.current

                            width: (calcKeys.width - (calcKeys.columns - 1) * calcKeys.spacing) / calcKeys.columns
                            height: keyLabel.implicitHeight + 2 * Theme.launcher.rowPadding
                            radius: Theme.launcher.fieldRadius
                            color: selected ? Theme.launcher.active : Theme.launcher.field

                            Text {
                                id: keyLabel
                                anchors.centerIn: parent
                                text: calcKey.modelData.label
                                color: calcKey.selected ? Theme.launcher.activeText : Theme.launcher.text
                                font: search.font
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onPositionChanged: win.current = calcKey.itemIndex
                                onClicked: win.choose(calcKey.modelData)
                            }
                        }
                    }
                }

                // --- calculator, in place of the list ---
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    x: pane.width + Theme.launcher.padding
                    width: list.width
                    spacing: Theme.launcher.rowSpacing
                    visible: win.calcMode && !win.showHistory

                    Text {
                        width: parent.width
                        text: calc.input || "=2+2*3   =15% * 240   =sqrt(2)"
                        elide: Text.ElideLeft
                        color: Theme.launcher.subtext
                        font: search.font
                    }

                    Text {
                        width: parent.width
                        text: calc.error || (calc.value ? "= " + calc.value : " ")
                        elide: Text.ElideRight
                        color: calc.error ? Theme.launcher.error : Theme.launcher.text
                        font.family: Theme.font.family
                        font.weight: Theme.launcher.fontWeight
                        font.pixelSize: calc.error ? Theme.launcher.fontSize : Theme.launcher.resultSize
                        opacity: calc.ready || calc.error ? 1 : 0.5 // dim while the result belongs to older input
                    }

                    Text {
                        width: parent.width
                        text: calc.ready && win.current < 0 ? "Enter copies the result" : win.current >= 0 ? "Enter inserts the key" : " "
                        color: Theme.launcher.subtext
                        font: search.font
                    }
                }
            }
        }
    }
}
