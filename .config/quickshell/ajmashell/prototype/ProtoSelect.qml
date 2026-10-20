// PROTOTYPE, ticket C10 — throwaway. A select: a pill with the current option; a click opens the list
// under it, the wheel steps through the options.

pragma ComponentBehavior: Bound

import QtQuick
import qs.orbit
import qs.singletons.theme

Item {
    id: select

    property var options: []
    property int index: 0
    property bool listOpen: false
    signal picked(int i)

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.height

    Pill {
        id: pill
        text: (select.options[select.index] ?? "") + " ▾"
        active: select.listOpen
        onClicked: select.listOpen = !select.listOpen

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                const n = select.options.length;
                select.picked((select.index + (wheel.angleDelta.y < 0 ? 1 : n - 1)) % n);
            }
        }
    }

    Rectangle {
        visible: select.listOpen
        anchors.top: pill.bottom
        anchors.topMargin: Theme.spacing.sm
        anchors.right: pill.right
        width: list.width + 2 * Theme.spacing.sm
        height: list.height + 2 * Theme.spacing.sm
        radius: Theme.radius.lg
        color: Theme.colors.surface_container_highest

        Column {
            id: list
            x: Theme.spacing.sm
            y: Theme.spacing.sm
            spacing: Theme.spacing.sm

            Repeater {
                model: select.options

                Pill {
                    required property string modelData
                    required property int index
                    text: modelData
                    active: index === select.index
                    onClicked: {
                        select.picked(index);
                        select.listOpen = false;
                    }
                }
            }
        }
    }
}
