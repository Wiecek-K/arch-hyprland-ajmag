// Media island — the MPRIS player on the Bar (ticket 17, D8): cover, track title (elided, never scrolled) and
// ⏮ ⏯ ⏭. A click on the cover or title opens the player popup (media/MediaPopup.qml; also IPC `media toggle`);
// no hover preview (user, 2026-10-07: removed). Hidden while no player has a track (media.mjs `candidates`).
// Shown player: the Media singleton, one for every screen.
// Own implementation; layout after serpantinum src/quickshell/bar/modules/MediaWidget.qml (cover + title open the
// popup, buttons beside them; no marquee, no position line), idea only:
// https://github.com/ilyamiro/serpantinum@67ee7053f2a555684e73a39a795db60750260d8d

import QtQuick
import Quickshell.Services.Mpris
import qs.media
import qs.singletons.media
import qs.singletons.theme
import "../singletons/media/media.mjs" as Logic

Island {
    id: root

    readonly property MprisPlayer player: Media.player

    function togglePopup(): void {
        if (player)
            popup.toggle();
    }

    spacing: Theme.spacing.lg
    opacity: player ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.motion.fast
        }
    }

    // cover + title: a click opens the popup (serpantinum: the same area opens its popup)
    Item {
        id: info
        anchors.verticalCenter: parent?.verticalCenter
        implicitWidth: infoRow.implicitWidth
        implicitHeight: Theme.bar.islandHeight

        Row {
            id: infoRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.md

            CoverArt {
                anchors.verticalCenter: parent.verticalCenter
                source: root.player?.trackArtUrl ?? ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(Math.ceil(implicitWidth), Theme.media.titleWidth)
                elide: Text.ElideRight
                text: Logic.title(root.player, Media.players)
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size
                font.weight: Theme.media.titleWeight
                color: Theme.media.text
            }
        }

        TapHandler {
            onTapped: popup.toggle()
        }
    }

    Row {
        anchors.verticalCenter: parent?.verticalCenter
        spacing: Theme.media.buttonGap

        MediaButton {
            icons: [Logic.ICONS.previous]
            enabled: root.player?.canGoPrevious ?? false
            onClicked: root.player?.previous()
        }

        MediaButton {
            icons: Logic.PLAY_ICONS
            text: Logic.playIcon(root.player?.isPlaying ?? false)
            enabled: root.player?.canTogglePlaying ?? false
            onClicked: root.player?.togglePlaying()
        }

        MediaButton {
            icons: [Logic.ICONS.next]
            enabled: root.player?.canGoNext ?? false
            onClicked: root.player?.next()
        }
    }

    MediaPopup {
        id: popup
        source: root
    }
}
