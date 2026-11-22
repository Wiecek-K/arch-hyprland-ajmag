// AudioLine — icon + name lines of the audio section (faza C ticket 17): the field with the current device, a device
// row of the open list (glyph in a circle, filled when chosen) and an app on the apps card (its icon, the note glyph
// without one). Lines: optional overline ("Output"), the name, optional subtitle (what it is / the tab title).
// Split out of AudioSection.qml after the code review (one block in three places). Own implementation.

import QtQuick
import qs.orbit
import qs.singletons.theme

Item {
    id: root

    property string glyph
    property string iconSource // an app's icon from the icon theme; "" draws the glyph
    property bool circle: true // glyph in a circle (devices); false: a bare icon (apps)
    property bool chosen: false // filled circle
    property string overline
    property string title
    property string subtitle

    implicitHeight: Math.max(icon.height, lines.implicitHeight)

    Item {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        width: root.circle ? Theme.control.circleSize : Theme.control.appIconSize
        height: width

        Rectangle {
            anchors.fill: parent
            visible: root.circle
            radius: width / 2
            color: root.chosen ? Theme.control.fill : Theme.control.circle
        }

        Image {
            anchors.fill: parent
            visible: root.iconSource !== ""
            source: root.iconSource
            sourceSize.width: width * 2
            sourceSize.height: height * 2
        }

        Text {
            anchors.centerIn: parent
            visible: root.iconSource === ""
            text: root.glyph
            font.family: Theme.font.family
            font.pixelSize: root.circle ? Theme.font.size : Theme.font.sizeLarge
            color: !root.circle ? Theme.control.subtext : root.chosen ? Theme.control.fillText : Theme.control.text
        }
    }

    Column {
        id: lines
        anchors.left: icon.right
        anchors.leftMargin: Theme.spacing.md
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        OrbitText {
            width: parent.width
            visible: text !== ""
            text: root.overline
            font.pixelSize: Theme.font.sizeTiny
            font.weight: Font.Normal
            color: Theme.control.subtext
        }

        OrbitText {
            width: parent.width
            text: root.title
            font.pixelSize: Theme.font.sizeSmall
            color: Theme.control.text
        }

        OrbitText {
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            font.pixelSize: Theme.font.sizeTiny
            font.weight: Font.Normal
            color: Theme.control.subtext
        }
    }
}
