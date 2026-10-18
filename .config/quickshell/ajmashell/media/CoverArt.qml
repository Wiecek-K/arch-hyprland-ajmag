// CoverArt — the track's cover (MPRIS mpris:artUrl, a file:// or https:// image) in a rounded square;
// a note icon while there is none or it is still loading (ticket 17).
// Own implementation; rounded clip with Quickshell's ClippingRectangle instead of serpantinum's MultiEffect mask.

import QtQuick
import Quickshell.Widgets
import qs.singletons.theme
import "../singletons/media/media.mjs" as Logic

ClippingRectangle {
    id: root

    property string source
    property int size: Theme.media.coverSize

    implicitWidth: size
    implicitHeight: size
    radius: Theme.media.coverRadius
    color: Theme.media.cover

    Text {
        anchors.centerIn: parent
        visible: image.status !== Image.Ready
        text: Logic.ICONS.music
        font.family: Theme.font.family
        font.pixelSize: Math.round(root.size / 2)
        color: Theme.media.coverIcon
    }

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // decode at the shown size: a Spotify cover is 640 px, kept in RAM per instance otherwise
        sourceSize.width: root.size
        sourceSize.height: root.size
    }
}
