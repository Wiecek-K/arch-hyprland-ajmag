// NotificationCard — one notification: icon, app name, title and body (ticket 10); a progress bar for the
// `value` hint and buttons for the app's actions (ticket 16). Used by the popups and the Centrum powiadomień.
// Own implementation; layout after serpantinum notifications/types/Default.qml (icon left, app name
// above the title, glyph when the icon does not load), idea only:
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// No expanding or swipe; grouping is the Centrum's job (control/ControlCenter.qml).

pragma ComponentBehavior: Bound

import QtQuick
import qs.singletons.theme
import "../singletons/notifications/notifications.mjs" as Logic

Rectangle {
    id: root

    required property string appName
    required property string summary
    required property string body
    required property string icon
    required property int urgency
    required property int progress // 0–100, -1 = no bar
    required property var actions // ListModel: identifier, text (notifications.mjs actionButtons)
    property bool showAppName: true // the Centrum shows it once, on the group header
    required property real time // ms, when it came (or was last updated)
    property bool showTime: false // the Centrum only: a popup on screen has just come, "now" says nothing (ticket 33)
    property real now: 0 // the Centrum's clock, read only with showTime
    property bool closable: false // an X while hovered: the Centrum (ticket 32) and the popups (ticket 37)
    // the popups: the X in place of the app icon, so the text needs no room for it (ticket 37, user 2026-10-12);
    // else in place of the time (Centrum)
    property bool closeOnIcon: false
    readonly property alias hovered: hover.hovered
    readonly property real timeReserve: showTime ? timeLabel.width + Theme.spacing.md : 0 // first line keeps clear of the time

    signal clicked
    signal actionInvoked(string identifier)
    signal closeRequested

    implicitHeight: Math.max(iconBox.height, texts.implicitHeight) + 2 * Theme.notifications.padding
    radius: Theme.radius.lg // like the Bar islands
    color: Theme.notifications.background
    border.width: urgency === 2 ? Theme.notifications.criticalBorder : 0 // NotificationUrgency.Critical
    border.color: Theme.notifications.critical

    HoverHandler {
        id: hover
    }

    // the buttons have their own TapHandler, but this one fires too: a tap on a button is not a click on the card
    TapHandler {
        onTapped: eventPoint => {
            const p = root.mapToItem(actionRow, eventPoint.position);
            const c = root.mapToItem(closeButton, eventPoint.position);
            if ((!actionRow.visible || !actionRow.contains(p)) && (!closeButton.visible || !closeButton.contains(c)))
                root.clicked();
        }
    }

    Item {
        id: iconBox

        x: Theme.notifications.padding
        y: Theme.notifications.padding
        width: Theme.notifications.iconSize
        height: Theme.notifications.iconSize

        // the icon fades out while the X takes its place (closeOnIcon); its size stays, nothing moves
        opacity: closeButton.shown && root.closeOnIcon ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motion.fast
            }
        }

        Image {
            id: image
            anchors.fill: parent
            source: root.icon
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: !image.visible
            text: Logic.BELL_ICON
            font.family: Theme.font.family
            font.pixelSize: Theme.font.sizeLarge
            color: Theme.notifications.subtext
        }
    }

    // time in the top-right corner (user, 2026-10-07), Centrum only (ticket 33); the first line leaves room for it
    Text {
        id: timeLabel
        anchors.right: parent.right
        anchors.rightMargin: Theme.notifications.padding
        y: Theme.notifications.padding
        visible: root.showTime
        text: root.showTime ? Logic.timeText(root.time, root.now) : ""
        textFormat: Text.PlainText
        font.family: Theme.font.family
        font.pixelSize: Theme.font.sizeSmall
        color: Theme.notifications.subtext
        opacity: closeButton.shown ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motion.fast
            }
        }
    }

    // X: close without the app's action and without a focus change; over the time, right-aligned with it,
    // or over the app icon (closeOnIcon), same size as the icon
    Rectangle {
        id: closeButton

        readonly property bool shown: root.closable && hover.hovered
        readonly property bool onIcon: root.closeOnIcon

        x: onIcon ? iconBox.x : root.width - width - Math.round(Theme.notifications.padding - (width - closeLabel.implicitWidth) / 2)
        y: onIcon ? iconBox.y : timeLabel.y + (timeLabel.height - height) / 2
        width: onIcon ? iconBox.width : Theme.notifications.closeSize
        height: width
        radius: height / 2
        visible: opacity > 0
        opacity: shown ? 1 : 0
        color: closeHover.hovered ? Theme.notifications.actionHover : Theme.transparent

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motion.fast
            }
        }

        Text {
            id: closeLabel
            anchors.centerIn: parent
            text: Logic.CLOSE_ICON
            font.family: Theme.font.family
            font.pixelSize: closeButton.onIcon ? Theme.font.sizeLarge : Theme.font.sizeSmall
            color: Theme.notifications.subtext
        }

        HoverHandler {
            id: closeHover
        }

        TapHandler {
            onTapped: root.closeRequested()
        }
    }

    Column {
        id: texts

        anchors.left: iconBox.right
        anchors.leftMargin: Theme.notifications.padding
        anchors.right: parent.right
        anchors.rightMargin: Theme.notifications.padding
        y: Theme.notifications.padding
        spacing: Theme.spacing.xs

        Text {
            width: parent.width
            visible: root.showAppName && text !== ""
            text: root.appName
            rightPadding: root.timeReserve
            elide: Text.ElideRight
            textFormat: Text.PlainText
            font.family: Theme.font.family
            font.pixelSize: Theme.font.sizeSmall
            color: Theme.notifications.subtext
        }

        Text {
            width: parent.width
            text: root.summary
            rightPadding: root.showAppName ? 0 : root.timeReserve
            elide: Text.ElideRight
            textFormat: Text.PlainText
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size
            font.weight: Theme.font.weight
            color: Theme.notifications.text
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.body
            wrapMode: Text.Wrap
            maximumLineCount: Theme.notifications.bodyLines
            elide: Text.ElideRight
            textFormat: Text.PlainText // bodyMarkupSupported is off: show what was sent
            font.family: Theme.font.family
            font.pixelSize: Theme.font.sizeSmall
            color: Theme.notifications.text
        }

        // hint `value` (copying files, downloads): updates live, the app re-sends the notification with the same id
        Rectangle {
            width: parent.width
            height: Theme.notifications.progressHeight
            visible: root.progress >= 0
            radius: height / 2
            color: Theme.notifications.progressTrack

            Rectangle {
                width: Math.round(parent.width * Math.max(0, root.progress) / 100)
                height: parent.height
                radius: height / 2
                color: Theme.notifications.progress
            }
        }

        Flow {
            id: actionRow

            width: parent.width
            visible: actionRepeater.count > 0
            spacing: Theme.spacing.sm

            Repeater {
                id: actionRepeater
                model: root.actions

                Rectangle {
                    id: button

                    required property string identifier
                    required property string text

                    width: Math.ceil(label.implicitWidth) + 2 * Theme.spacing.lg
                    height: Theme.notifications.actionHeight
                    radius: height / 2
                    color: buttonHover.hovered ? Theme.notifications.actionHover : Theme.notifications.action

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: button.text
                        textFormat: Text.PlainText
                        font.family: Theme.font.family
                        font.pixelSize: Theme.font.sizeSmall
                        color: Theme.notifications.text
                    }

                    HoverHandler {
                        id: buttonHover
                    }

                    TapHandler {
                        onTapped: root.actionInvoked(button.identifier)
                    }
                }
            }
        }
    }
}
