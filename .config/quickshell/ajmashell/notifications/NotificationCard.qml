// NotificationCard — one notification: icon, app name, title and body (ticket 10).
// Own implementation; layout after serpantinum notifications/types/Default.qml (icon left, app name
// above the title, glyph when the icon does not load), idea only:
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// Kept small on purpose: no actions, expanding, swipe or grouping (full Notification centre, ticket 16).

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
    readonly property alias hovered: hover.hovered

    signal clicked

    implicitHeight: Math.max(iconBox.height, texts.implicitHeight) + 2 * Theme.notifications.padding
    radius: Theme.radius.lg // like the Bar islands
    color: Theme.notifications.background
    border.width: urgency === 2 ? Theme.notifications.criticalBorder : 0 // NotificationUrgency.Critical
    border.color: Theme.notifications.critical

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.clicked()
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
            visible: text !== ""
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
    }
}
