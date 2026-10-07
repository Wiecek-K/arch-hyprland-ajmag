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
    readonly property alias hovered: hover.hovered

    signal clicked
    signal actionInvoked(string identifier)

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
            if (!actionRow.visible || !actionRow.contains(p))
                root.clicked();
        }
    }

    Item {
        id: iconBox

        x: Theme.notifications.padding
        y: Theme.notifications.padding
        width: Theme.notifications.iconSize
        height: Theme.notifications.iconSize

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
            elide: Text.ElideRight
            textFormat: Text.PlainText
            font.family: Theme.font.family
            font.pixelSize: Theme.font.sizeSmall
            color: Theme.notifications.subtext
        }

        Text {
            width: parent.width
            text: root.summary
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
