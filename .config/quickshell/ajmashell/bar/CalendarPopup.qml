// CalendarPopup — a click on the Bar's clock (ticket 42): the month from Monday with ISO week numbers, today
// marked, Sundays and Polish statutory holidays in Theme.calendar.dayOff; the holiday's name shows in the line
// under the grid while the pointer is on its day (user, 2026-10-14).
// Months: wheel (up = next, like Waybar's "shift_up" and our workspaces), ← →, the ‹ › buttons; the title and
// Home go back to today. Opens on the current month.
// A small popup like the audio popup (user, 2026-10-14): Theme.control colours, the look's background, no flare.
// Hangs under the clock; closes on a click outside (HyprlandFocusGrab), on Esc and on a second click on the clock.
// Pure logic: calendar.mjs (tests tools/test-calendar.mjs).
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

    readonly property int todayYear: now.getFullYear()
    readonly property int todayMonth: now.getMonth() + 1
    readonly property int todayDay: now.getDate()

    property int year: todayYear // month shown
    property int month: todayMonth
    property string hoveredName: "" // holiday under the pointer
    property real wheelRest: 0

    readonly property var grid: Logic.monthGrid(year, month)

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
        year = todayYear;
        month = todayMonth;
    }

    function shift(delta: int): void {
        const to = Logic.shiftMonth(year, month, delta);
        year = to.year;
        month = to.month;
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

    implicitWidth: column.implicitWidth + 2 * Theme.control.padding
    implicitHeight: column.implicitHeight + 2 * Theme.control.padding
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

        Column {
            id: column
            x: Theme.control.padding
            y: Theme.control.padding
            spacing: Theme.spacing.sm

            // ‹ Październik 2026 ›
            Item {
                width: parent.width
                height: Theme.calendar.cell

                CalendarButton {
                    anchors.left: parent.left
                    text: "\uf053" // nf-fa-chevron_left
                    onClicked: root.shift(-1)
                }

                CalendarButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Logic.title(root.year, root.month)
                    onClicked: root.showToday()
                }

                CalendarButton {
                    anchors.right: parent.right
                    text: "\uf054" // nf-fa-chevron_right
                    onClicked: root.shift(1)
                }
            }

            // weekday header, empty corner over the week numbers
            Row {
                Item {
                    width: Theme.calendar.weekWidth
                    height: 1
                }

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

                    OrbitText {
                        width: Theme.calendar.weekWidth
                        height: Theme.calendar.cell
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Theme.font.sizeSmall
                        color: Theme.calendar.subtext
                        text: week.modelData.week
                    }

                    Repeater {
                        model: week.modelData.days

                        Rectangle {
                            id: day

                            required property var modelData
                            readonly property var off: Logic.dayOff(modelData.year, modelData.month, modelData.day)
                            readonly property bool today: modelData.year === root.todayYear && modelData.month === root.todayMonth && modelData.day === root.todayDay

                            width: Theme.calendar.cell
                            height: Theme.calendar.cell
                            radius: height / 2
                            color: today ? Theme.calendar.today : dayHover.hovered ? Theme.calendar.hover : Theme.transparent
                            opacity: modelData.inMonth ? 1 : Theme.calendar.outside

                            OrbitText {
                                anchors.centerIn: parent
                                font.pixelSize: Theme.font.sizeSmall
                                color: day.today ? Theme.calendar.todayText : day.off.off ? Theme.calendar.dayOff : Theme.calendar.text
                                text: day.modelData.day
                            }

                            HoverHandler {
                                id: dayHover
                                onHoveredChanged: {
                                    if (hovered)
                                        root.hoveredName = day.off.name;
                                    else if (root.hoveredName === day.off.name)
                                        root.hoveredName = "";
                                }
                            }
                        }
                    }
                }
            }

            // holiday under the pointer; the line keeps its height, so the popup never jumps
            OrbitText {
                width: parent.width
                height: Theme.calendar.cell
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.font.sizeSmall
                color: Theme.calendar.dayOff
                text: root.hoveredName
            }
        }
    }

    // round button with a hover fill, like the Orbita's soft pills
    component CalendarButton: Rectangle {
        id: button

        property alias text: label.text
        signal clicked

        width: Math.max(Theme.calendar.cell, label.implicitWidth + 2 * Theme.spacing.lg)
        height: Theme.calendar.cell
        radius: height / 2
        color: buttonHover.hovered ? Theme.calendar.hover : Theme.transparent

        OrbitText {
            id: label
            anchors.centerIn: parent
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
