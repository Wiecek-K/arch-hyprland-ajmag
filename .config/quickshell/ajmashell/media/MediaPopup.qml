// MediaPopup — the player popup, opened by a click on the media island's cover or title (ticket 17, D8, B11 #01
// without the equaliser): cover, title, artist, album, the player choice when several play, a seek slider with
// the position, and ⏮ ⏯ ⏭.
// A big popup: background and lens flare by the look like the Orbita and the Centrum sterowania (Look.qml), blur
// from the ajmashell-bar layer rule (blur_popups). Hangs under its island; closes on a click outside
// (HyprlandFocusGrab), on Esc and on a second click — grab as in control/AudioPopup.qml.
// Own implementation; layout after serpantinum src/quickshell/media/MusicPopup.qml (cover beside the track info,
// player dropdown, progress bar with times, ⏮ ⏯ ⏭ row; no equaliser, vinyl disc, cover colours or visualiser), idea
// only: https://github.com/ilyamiro/serpantinum@67ee7053f2a555684e73a39a795db60750260d8d

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs.control
import qs.orbit
import qs.singletons.look
import qs.singletons.media
import qs.singletons.theme
import "../singletons/media/media.mjs" as Logic

PopupWindow {
    id: root

    required property Item source // island the popup hangs under
    readonly property MprisPlayer player: Media.player
    readonly property var time: Logic.timeline(player, Media.knownLength) // position, length, text; unknown without a length (Zen / YouTube)
    property real shift: 0 // px right, so the popup stays on screen (set on open)

    function toggle(): void {
        // here, not in a binding: mapToItem does not follow the island's position, which settles after start
        if (!visible)
            shift = Math.max(0, Theme.control.margin + implicitWidth - source.mapToItem(null, source.width, 0).x);
        visible = !visible;
    }

    function seek(fraction: real): void {
        if (!time.seekable)
            return;
        player.position = Logic.seekPosition(fraction, time.length);
        player.positionChanged();
    }

    // the grab refuses a window that is not mapped yet, so arm it after the popup shows (as the Orbita)
    onVisibleChanged: Qt.callLater(() => {
        grab.active = root.visible;
        if (root.visible)
            panel.forceActiveFocus();
    })

    // the last player went away: nothing left to show
    onPlayerChanged: {
        if (!player)
            visible = false;
    }

    HyprlandFocusGrab {
        id: grab
        windows: [root]
        onCleared: root.visible = false
    }

    // MPRIS sends no position updates while playing: re-read it only while the popup is open
    Timer {
        interval: Theme.media.poll
        repeat: true
        running: root.visible && (root.player?.isPlaying ?? false)
        onTriggered: root.player?.positionChanged()
    }

    visible: false
    anchor.item: source
    // Under the island's right edge, growing left: that edge touches the clock and stays put, while the left one
    // moves with the title's length (a new track would shift an open popup). Moved right when it would stick out
    // of the screen's left edge (Hyprland does not slide it).
    anchor.rect.x: shift
    anchor.rect.y: 0
    anchor.rect.width: source.width
    anchor.rect.height: source.height + Theme.bar.tooltip.gap
    // qmltypes give these as Edges::Flags, which qmllint cannot resolve
    anchor.edges: Edges.Bottom | Edges.Right // qmllint disable missing-type
    anchor.gravity: Edges.Bottom | Edges.Left // qmllint disable missing-type

    implicitWidth: Theme.media.popupWidth
    implicitHeight: content.implicitHeight + 2 * Theme.control.padding
    color: Theme.transparent // only the rounded box below is drawn

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Theme.radius.lg
        color: Look.background(Theme.control)
        clip: true // the flare reaches past the panel

        focus: true
        Keys.onEscapePressed: root.visible = false

        OrbitBackdrop {
            id: backdrop
            anchors.fill: parent
            visible: Look.current.flare

            Timer {
                interval: 1000 / Theme.orbit.fps
                repeat: true
                running: root.visible && backdrop.visible && Look.current.motion
                onTriggered: backdrop.angle = (backdrop.angle + 2 * Math.PI * interval / Theme.orbit.period) % (2 * Math.PI)
            }
        }

        Column {
            id: content
            x: Theme.control.padding
            y: Theme.control.padding
            width: parent.width - 2 * Theme.control.padding
            spacing: Theme.control.spacing

            Row {
                width: parent.width
                spacing: Theme.control.padding

                CoverArt {
                    id: cover
                    size: Theme.media.popupCover
                    source: root.player?.trackArtUrl ?? ""
                }

                Column {
                    width: parent.width - cover.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing.sm

                    OrbitText {
                        width: parent.width
                        text: Logic.title(root.player, Media.players)
                        font.pixelSize: Theme.font.sizeLarge
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }

                    OrbitText {
                        width: parent.width
                        visible: text !== ""
                        text: Logic.artist(root.player)
                        color: Theme.control.subtext
                    }

                    OrbitText {
                        width: parent.width
                        visible: text !== ""
                        text: root.player?.trackAlbum ?? ""
                        font.pixelSize: Theme.font.sizeSmall
                        color: Theme.control.subtext
                    }

                    // the player choice (ticket 17: "wybór aktywnego odtwarzacza przy kilku"); one player: its name
                    OrbitText {
                        width: parent.width
                        visible: Media.players.length < 2
                        text: Media.label(root.player)
                        font.pixelSize: Theme.font.sizeSmall
                        color: Theme.control.subtext
                    }

                    Flow {
                        width: parent.width
                        visible: Media.players.length > 1
                        spacing: Theme.spacing.sm

                        Repeater {
                            model: Media.players

                            Pill {
                                required property MprisPlayer modelData
                                width: Math.min(implicitWidth, parent.width)
                                text: Media.label(modelData)
                                active: modelData === root.player
                                onClicked: Media.select(modelData)
                            }
                        }
                    }
                }
            }

            ControlSlider {
                id: seekSlider

                property real pending: -1 // seek once on release, not on every drag step

                width: parent.width
                enabled: root.time.seekable
                opacity: enabled ? 1 : Theme.orbit.dimmed
                iconClickable: false
                icon: Logic.ICONS.music
                position: root.time.fraction
                text: dragging ? Logic.timeText(Logic.seekPosition(dragPosition, root.time.length), root.time.length) : root.time.text
                onMoved: fraction => {
                    if (dragging) {
                        pending = fraction;
                        return;
                    }
                    root.seek(fraction); // wheel
                }
                onDraggingChanged: {
                    if (dragging || pending < 0)
                        return;
                    root.seek(pending);
                    pending = -1;
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.control.spacing

                Pill {
                    width: Theme.media.popupButtonWidth
                    fontSize: Theme.font.sizeLarge
                    text: Logic.ICONS.previous
                    enabled: root.player?.canGoPrevious ?? false
                    onClicked: root.player?.previous()
                }

                Pill {
                    width: Theme.media.popupButtonWidth
                    fontSize: Theme.font.sizeLarge
                    active: true
                    text: Logic.playIcon(root.player?.isPlaying ?? false)
                    enabled: root.player?.canTogglePlaying ?? false
                    onClicked: root.player?.togglePlaying()
                }

                Pill {
                    width: Theme.media.popupButtonWidth
                    fontSize: Theme.font.sizeLarge
                    text: Logic.ICONS.next
                    enabled: root.player?.canGoNext ?? false
                    onClicked: root.player?.next()
                }
            }
        }
    }
}
