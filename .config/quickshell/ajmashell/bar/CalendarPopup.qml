// CalendarPopup — a click on the Bar's clock (ticket 42). Variant B of the UI prototype (user, 2026-10-14):
// left a panel with today — big day number, weekday, date with the ISO week, today's holiday or the next one with
// its distance; right the month from Monday, today marked, Sundays and Polish statutory holidays in
// Theme.calendar.dayOff. A left click on a day shows that day in the panel (its holiday name, distance from today),
// a right click goes back to today (user, 2026-10-14).
// Months: wheel (up = next, like Waybar's "shift_up" and our workspaces), ← →, the ‹ › buttons; the title and
// Home go back to today's month. Opens on today.
// The look's background and lens flare like the big popups (user, 2026-10-14), Theme.control colours.
// Hangs under the clock; closes on a click outside (HyprlandFocusGrab), on Esc and on a second click on the clock.
// Pure logic: calendar.mjs (tests tools/test-calendar.mjs). The prototype with all four variants:
// branch prototype/ticket-42-calendar-ui in the dotfiles repo.
// Own implementation; popup placement and focus grab as in control/AudioPopup.qml. Title click back to today and
// wheel over the month after caelestia-dots/shell modules/dashboard/dash/Calendar.qml (GPL-3.0), idea only:
// https://github.com/caelestia-dots/shell/blob/a3a8fe59aba2c0048ab02dc817748678f96076ff/modules/dashboard/dash/Calendar.qml

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.orbit
import qs.singletons.barpopups
import qs.singletons.theme
import qs.singletons.look
import "calendar.mjs" as Logic
import "wheel.mjs" as Wheel

PopupWindow {
    id: root

    required property Item source // the clock island
    required property date now // the clock's SystemClock: today moves on at midnight while open

    readonly property var today: ({ year: now.getFullYear(), month: now.getMonth() + 1, day: now.getDate() })

    property int year: today.year // month shown
    property int month: today.month
    property var selected: null // clicked day { year, month, day }; null = today
    property real wheelRest: 0

    readonly property var grid: Logic.monthGrid(year, month)
    readonly property var info: Logic.describe(selected ?? today, today) // the left panel

    function toggle(): void {
        if (!visible)
            showToday();
        visible = !visible;
    }

    // the popup followed the focus to this monitor (ticket 27)
    function openPopup(): void {
        if (!visible)
            toggle();
    }

    function showToday(): void {
        year = today.year;
        month = today.month;
        selected = null;
    }

    function shift(delta: int): void {
        const to = Logic.shiftMonth(year, month, delta);
        year = to.year;
        month = to.month;
    }

    function same(a: var, b: var): bool {
        return !!a && !!b && a.year === b.year && a.month === b.month && a.day === b.day;
    }

    // the grab refuses a window that is not mapped yet, so arm it after the popup shows (as the Orbita)
    onVisibleChanged: Qt.callLater(() => {
        grab.active = root.visible;
        if (root.visible)
            panel.forceActiveFocus();
    })

    HyprlandFocusGrab {
        id: grab
        windows: [root, ...BarPopups.bars]
        onCleared: root.visible = false
    }

    // ticket 27: closes on a press on the Bar outside the clock; follows the focused monitor
    BarElement {
        open: root.visible
        owners: [root.source]
        screenName: root.screen?.name ?? ""
        onClose: root.visible = false
        onFollow: name => {
            root.visible = false;
            BarPopups.reopen("calendar", null, name);
        }
    }

    visible: false
    anchor.item: source
    // centred under the clock, which sits on the monitor's axis, so it never sticks out of the screen
    anchor.rect.x: Math.round((source.width - implicitWidth) / 2)
    anchor.rect.y: 0
    anchor.rect.width: source.width
    anchor.rect.height: source.height + Theme.bar.tooltip.gap
    // qmltypes give these as Edges::Flags, which qmllint cannot resolve
    anchor.edges: Edges.Bottom | Edges.Left // qmllint disable missing-type
    anchor.gravity: Edges.Bottom | Edges.Right // qmllint disable missing-type

    implicitWidth: content.implicitWidth + 2 * Theme.control.padding
    implicitHeight: content.implicitHeight + 2 * Theme.control.padding
    color: Theme.transparent // only the rounded box below is drawn

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Theme.radius.lg
        color: Look.background(Theme.control)

        focus: true
        Keys.onEscapePressed: root.visible = false
        Keys.onLeftPressed: root.shift(-1)
        Keys.onRightPressed: root.shift(1)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Home)
                root.showToday();
        }

        // MouseArea, not WheelHandler, like the Bar's islands
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                const step = Wheel.wheel(root.wheelRest, wheel.angleDelta.y);
                root.wheelRest = step.rest;
                if (step.step)
                    root.shift(step.step);
            }
        }

        // right click anywhere: back to today in the left panel
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: root.selected = null
        }

        OrbitBackdrop {
            anchors.fill: parent
            visible: Look.current.flare
            open: root.visible
        }

        Row {
            id: content
            x: Theme.control.padding
            y: Theme.control.padding
            spacing: Theme.control.spacing

            // left: today or the clicked day. Shorter than the grid, so its text never changes the popup's size.
            Column {
                width: Theme.calendar.panelWidth
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing.sm

                OrbitText {
                    font.pixelSize: Theme.calendar.bigDay
                    color: root.info.off ? Theme.calendar.dayOff : Theme.calendar.text
                    text: root.info.day
                }

                OrbitText {
                    width: parent.width
                    font.pixelSize: Theme.font.sizeLarge
                    color: Theme.calendar.text
                    text: root.info.weekday
                }

                PanelText {
                    text: root.info.date
                }

                PanelText {
                    visible: text !== ""
                    text: root.info.when
                }

                Item {
                    width: 1
                    height: Theme.spacing.lg
                }

                // the day's own holiday, a plain Sunday, or the next holiday from today
                PanelText {
                    text: root.info.holiday !== "" ? "Święto" : root.info.off ? "Dzień wolny" : root.info.next ? "Najbliższe święto — " + root.info.next.when : ""
                }

                PanelText {
                    font.pixelSize: Theme.font.size
                    color: Theme.calendar.dayOff
                    text: root.info.holiday !== "" ? root.info.holiday : root.info.off ? "" : root.info.next?.name ?? ""
                }

                PanelText {
                    visible: text !== ""
                    text: root.info.holiday === "" && !root.info.off ? root.info.next?.date ?? "" : ""
                }
            }

            Rectangle {
                width: 1
                height: monthView.height
                color: Theme.control.separator
            }

            // right: ‹ Październik 2026 ›, weekdays, 6 weeks
            Column {
                id: monthView
                spacing: Theme.spacing.xs

                Item {
                    width: 7 * Theme.calendar.cell
                    height: Theme.calendar.cell

                    CalendarButton {
                        anchors.left: parent.left
                        text: "" // nf-fa-chevron_left
                        onClicked: root.shift(-1)
                    }

                    CalendarButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        small: true
                        text: Logic.title(root.year, root.month)
                        onClicked: root.showToday()
                    }

                    CalendarButton {
                        anchors.right: parent.right
                        text: "" // nf-fa-chevron_right
                        onClicked: root.shift(1)
                    }
                }

                Row {
                    Repeater {
                        model: Logic.WEEKDAYS

                        OrbitText {
                            required property string modelData
                            required property int index

                            width: Theme.calendar.cell
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Theme.font.sizeSmall
                            color: index === 6 ? Theme.calendar.dayOff : Theme.calendar.subtext
                            text: modelData
                        }
                    }
                }

                Repeater {
                    model: root.grid

                    Row {
                        id: week
                        required property var modelData

                        Repeater {
                            model: week.modelData.days

                            Rectangle {
                                id: day

                                required property var modelData
                                readonly property bool off: Logic.dayOff(modelData.year, modelData.month, modelData.day).off
                                readonly property bool today: root.same(modelData, root.today)

                                width: Theme.calendar.cell
                                height: Theme.calendar.cell
                                radius: height / 2
                                color: today ? Theme.calendar.today : dayHover.hovered ? Theme.calendar.hover : Theme.transparent
                                // the clicked day: a ring in today's colour
                                border.width: root.same(modelData, root.selected) && !today ? Theme.bar.ringWidth : 0
                                border.color: Theme.calendar.today
                                opacity: modelData.inMonth ? 1 : Theme.calendar.outside

                                OrbitText {
                                    anchors.centerIn: parent
                                    font.pixelSize: Theme.font.sizeSmall
                                    color: day.today ? Theme.calendar.todayText : day.off ? Theme.calendar.dayOff : Theme.calendar.text
                                    text: day.modelData.day
                                }

                                HoverHandler {
                                    id: dayHover
                                }

                                TapHandler {
                                    onTapped: root.selected = day.modelData
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // wrapped small text of the left panel
    component PanelText: OrbitText {
        width: Theme.calendar.panelWidth
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        font.pixelSize: Theme.font.sizeSmall
        color: Theme.calendar.subtext
    }

    // round button with a hover fill, like the Orbita's soft pills
    component CalendarButton: Rectangle {
        id: button

        property alias text: label.text
        property bool small: false
        signal clicked

        width: Math.max(Theme.calendar.cell, label.implicitWidth + 2 * Theme.spacing.lg)
        height: Theme.calendar.cell
        radius: height / 2
        color: buttonHover.hovered ? Theme.calendar.hover : Theme.transparent

        OrbitText {
            id: label
            anchors.centerIn: parent
            font.pixelSize: button.small ? Theme.font.sizeSmall : Theme.font.size
            color: Theme.calendar.text
        }

        HoverHandler {
            id: buttonHover
        }

        TapHandler {
            onTapped: button.clicked()
        }
    }
}
