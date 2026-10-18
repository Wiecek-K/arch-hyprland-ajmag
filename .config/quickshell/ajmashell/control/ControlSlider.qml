// ControlSlider — thick rounded slider of the Centrum sterowania and the audio popup (ticket 14):
// the filled part carries the icon, the percent sits at the right end. Click or drag sets the level,
// the wheel moves it 5% per notch, a click on the icon fires iconClicked (mute).
// Own implementation; look after the sliders on end-4's right sidebar (B11 #12 screenshot, idea only;
// ii/modules/ii/sidebarRight/QuickSliders.qml in https://github.com/end-4/dots-hyprland at 2f0c8bf, GPL-3.0).

import QtQuick
import qs.singletons.theme
import "control.mjs" as Logic
import "../bar/wheel.mjs" as Wheel

Item {
    id: root

    property real position: 0 // 0–1, the level shown when not dragged
    property string icon
    property string text // percent at the right end
    property bool muted: false
    property bool iconClickable: true

    signal moved(real position)
    signal iconClicked

    readonly property bool dragging: mouse.pressed && !mouse.onIcon
    property real dragPosition: 0
    property real wheelRest: 0
    readonly property real shown: dragging ? dragPosition : position

    implicitHeight: Theme.control.sliderHeight

    function positionAt(x: real): real {
        return Math.max(0, Math.min(1, x / width));
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.control.track
    }

    Rectangle {
        // never narrower than the round end, so the icon always sits in the fill
        width: Math.round(root.height + root.shown * (root.width - root.height))
        height: parent.height
        radius: height / 2
        color: root.muted ? Theme.control.muted : Theme.control.fill
    }

    Text {
        width: root.height
        height: root.height
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.icon
        font.family: Theme.font.family
        font.pixelSize: Theme.font.size
        color: Theme.control.fillText
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing.lg
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        font.family: Theme.font.family
        font.pixelSize: Theme.font.sizeSmall
        font.weight: Theme.font.weight
        color: Theme.control.text
    }

    MouseArea {
        id: mouse

        property bool onIcon: false

        anchors.fill: parent
        onPressed: event => {
            onIcon = root.iconClickable && event.x < root.height;
            if (onIcon)
                return;
            root.dragPosition = root.positionAt(event.x);
            root.moved(root.dragPosition);
        }
        onPositionChanged: event => {
            if (!root.dragging)
                return;
            root.dragPosition = root.positionAt(event.x);
            root.moved(root.dragPosition);
        }
        onClicked: event => {
            if (onIcon && event.x < root.height)
                root.iconClicked();
        }
        onWheel: wheel => {
            const step = Wheel.wheel(root.wheelRest, wheel.angleDelta.y); // touchpads send small deltas
            root.wheelRest = step.rest;
            if (step.step)
                root.moved(Logic.wheelPosition(root.position, step.step));
        }
    }
}
