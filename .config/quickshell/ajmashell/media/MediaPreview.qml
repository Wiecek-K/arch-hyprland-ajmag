// MediaPreview — hover preview under the media island's cover and title (ticket 17, D8): bigger cover, title,
// artist, album and the position, dressed like the Bar tooltips. Read only; a click opens MediaPopup.
// A popup window like bar/BarTooltip.qml (the 42 px Bar window would clip it), shown after the same rest.
// Own implementation; content after serpantinum src/quickshell/media/MusicPopup.qml (cover, title, artist,
// position / length), idea only: https://github.com/ilyamiro/serpantinum@67ee7053f2a555684e73a39a795db60750260d8d

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.singletons.media
import qs.singletons.theme
import "../singletons/media/media.mjs" as Logic

PopupWindow {
    id: root

    required property Item target
    property bool hovered: false
    readonly property MprisPlayer player: Media.player
    readonly property var time: Logic.timeline(player, Media.knownLength) // unknown without a length (Zen / YouTube): no bar, no time

    anchor.item: target
    anchor.rect.x: 0
    anchor.rect.y: 0
    anchor.rect.width: target.width
    anchor.rect.height: target.height + Theme.bar.tooltip.gap
    // qmltypes give these as Edges::Flags, which qmllint cannot resolve
    anchor.edges: Edges.Bottom // qmllint disable missing-type
    anchor.gravity: Edges.Bottom // qmllint disable missing-type

    visible: delay.done && hovered && player !== null
    implicitWidth: Theme.media.previewWidth
    implicitHeight: Math.max(Theme.media.previewCover, info.implicitHeight) + 2 * Theme.bar.tooltip.padding
    color: Theme.transparent // only the rounded box below is drawn

    Timer {
        id: delay
        property bool done: false
        interval: Theme.motion.tooltipDelay
        running: root.hovered
        onTriggered: done = true
    }

    onHoveredChanged: delay.done = false

    // MPRIS sends no position updates while playing: re-read it only while the preview is shown
    Timer {
        interval: Theme.media.poll
        repeat: true
        running: root.visible && (root.player?.isPlaying ?? false)
        onTriggered: root.player?.positionChanged()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.lg
        color: Theme.media.previewBackground

        CoverArt {
            id: cover
            x: Theme.bar.tooltip.padding
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.media.previewCover
            source: root.player?.trackArtUrl ?? ""
        }

        Column {
            id: info
            anchors.left: cover.right
            anchors.leftMargin: Theme.spacing.lg
            anchors.right: parent.right
            anchors.rightMargin: Theme.bar.tooltip.padding + Theme.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.xs

            PreviewText {
                text: Logic.title(root.player, Media.players)
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            PreviewText {
                visible: text !== ""
                text: Logic.artist(root.player)
                color: Theme.media.previewSubtext
            }

            PreviewText {
                visible: text !== ""
                text: root.player?.trackAlbum ?? ""
                color: Theme.media.previewSubtext
            }

            Item {
                width: parent.width
                height: Theme.spacing.sm
            }

            Rectangle {
                visible: root.time.known
                width: parent.width
                height: Theme.media.progressHeight
                radius: height / 2
                color: Theme.media.progressTrack

                Rectangle {
                    width: Math.round(parent.width * root.time.fraction)
                    height: parent.height
                    radius: height / 2
                    color: Theme.media.progress
                }
            }

            PreviewText {
                visible: text !== ""
                text: [Media.players.length > 1 ? Media.label(root.player) : "", root.time.text].filter(part => part !== "").join(" · ")
                color: Theme.media.previewSubtext
            }
        }
    }

    component PreviewText: Text {
        width: parent?.width ?? 0
        elide: Text.ElideRight
        font.family: Theme.font.family
        font.pixelSize: Theme.font.sizeSmall
        font.weight: Theme.font.weight
        color: Theme.media.previewText
    }
}
