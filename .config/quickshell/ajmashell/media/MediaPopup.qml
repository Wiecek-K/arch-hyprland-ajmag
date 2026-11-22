// MediaPopup — the player popup, opened by a click on the media island's cover or title (ticket 17, D8, B11 #01
// without the equaliser): cover, title, artist, album, the player choice when several play, a seek slider with
// the position, and ⏮ ⏯ ⏭. Ticket c14: a double click on the cover, the texts or a player's pill goes to the window of
// that player's app (Media.focusApp) and closes the popup.
// Faza C ticket 29: keyboard control (map: user, 2026-11-09; media.mjs keyAction): space play / pause, Tab / Shift+Tab
// next / previous player, ← / → seek 10 s, Shift+← / Shift+→ and , / . previous / next track, ↑ / ↓ the player's own
// volume, Enter its app, Esc close. Each control shows its key after a long hover (control/HoverHint.qml). SUPER+P opens the popup
// on the focused monitor (IpcHandler "media" in bar/Bar.qml); keyboard focus is in the popup while it is open.
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
import qs.look
import qs.orbit
import qs.singletons.barpopups
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
        if (!visible) {
            shift = Math.max(0, Theme.control.margin + Theme.media.popupWidth - source.mapToItem(null, source.width, 0).x);
            // `time` still holds the position from the last close: refresh it before the first frame, not a poll later
            player?.positionChanged();
        }
        visible = !visible;
    }

    // ticket c14: the shown player's app (user, 2026-11-07: the program in the popup, not the one making sound)
    // stays open when nothing happened (no window, no Raise; user, 2026-11-07)
    function goToApp(p: MprisPlayer): void {
        if (Media.focusApp(p))
            visible = false;
    }

    function seek(fraction: real): void {
        if (time.seekable)
            seekTo(Logic.seekPosition(fraction, time.length));
    }

    function seekTo(position: real): void {
        player.position = position;
        player.positionChanged();
    }

    // ticket 29: a key pressed in the popup, or on the Bar while the popup is open (BarPopups.keyPressed: opened from
    // the keyboard, the focus grab gives the keyboard to a Bar until the pointer enters the popup)
    function key(event: KeyEvent): void {
        const action = Logic.keyAction(event.key, (event.modifiers & Qt.ShiftModifier) !== 0);
        if (!action)
            return; // not ours: let it through
        event.accepted = true;
        if (!event.isAutoRepeat || Logic.repeats(action))
            run(action);
    }

    Connections {
        target: BarPopups
        enabled: root.visible

        function onKeyPressed(event: KeyEvent): void {
            root.key(event);
        }
    }

    // ticket 29: one key's action (media.mjs keyAction); an action the player cannot do does nothing
    function run(action: string): void {
        const p = player;
        switch (action) {
        case "togglePlaying":
            if (p?.canTogglePlaying)
                p.togglePlaying();
            break;
        case "nextPlayer":
        case "previousPlayer":
            {
                const other = Logic.cyclePlayer(Media.players, p, action === "nextPlayer" ? 1 : -1);
                if (other)
                    Media.select(other);
                break;
            }
        case "seekBack":
        case "seekForward":
            {
                const target = Logic.seekBy(time, action === "seekForward" ? 1 : -1);
                if (target !== null)
                    seekTo(target);
                break;
            }
        case "previous":
            if (p?.canGoPrevious)
                p.previous();
            break;
        case "next":
            if (p?.canGoNext)
                p.next();
            break;
        case "volumeUp":
        case "volumeDown":
            {
                const volume = Logic.volumeBy(p, action === "volumeUp" ? 1 : -1);
                if (volume !== null)
                    p.volume = volume;
                break;
            }
        case "goToApp":
            goToApp(p);
            break;
        case "close":
            visible = false;
            break;
        }
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
        windows: [root, ...BarPopups.bars]
        onCleared: root.visible = false
    }

    // ticket 27: closes on a press on the Bar outside its own islands; ticket 52: and on a change of the focused workspace
    BarElement {
        open: root.visible
        owners: [root.source]
        screenName: root.screen?.name ?? ""
        onClose: root.visible = false
    }

    // MPRIS sends no position updates while playing: re-read it only while the popup is open
    Timer {
        interval: Theme.media.poll
        repeat: true
        triggeredOnStart: true // playback resumed with the popup open: no stale second
        running: root.visible && (root.player?.isPlaying ?? false)
        onTriggered: root.player?.positionChanged()
    }

    visible: false
    anchor.item: source
    // Under the island's right edge, growing left: that edge touches the clock and stays put, while the left one
    // moves with the title's length (a new track would shift an open popup). Moved right when it would stick out
    // of the screen's left edge (Hyprland does not slide it).
    anchor.rect.x: shift + Theme.shadow.margin // the box stays where it was (ticket C13: the shadow's band around it)
    anchor.rect.y: 0
    anchor.rect.width: source.width
    anchor.rect.height: source.height + Theme.bar.popupGap - Theme.shadow.margin
    // qmltypes give these as Edges::Flags, which qmllint cannot resolve
    anchor.edges: Edges.Bottom | Edges.Right // qmllint disable missing-type
    anchor.gravity: Edges.Bottom | Edges.Left // qmllint disable missing-type
    // ticket C13: the shadow's band may stick out of the screen; sliding the window back would move the box
    anchor.adjustment: PopupAdjustment.None // qmllint disable missing-type

    // the box plus the shadow's band (ticket C13); clicks in the band pass through
    implicitWidth: Theme.media.popupWidth + 2 * Theme.shadow.margin
    implicitHeight: content.implicitHeight + 2 * Theme.control.padding + 2 * Theme.shadow.margin
    color: Theme.transparent // only the rounded box below is drawn
    mask: Region {
        item: panel
    }

    LookShadow {
        target: panel
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        anchors.margins: Theme.shadow.margin
        radius: Theme.radius.lg
        color: Theme.transparent // LookBackground draws the look's background
        LookBackground {}
        clip: true // the flare reaches past the panel

        focus: true
        Keys.onPressed: event => root.key(event)

        OrbitBackdrop {
            anchors.fill: parent
            visible: Look.current.flare
            open: root.visible
        }

        Column {
            id: content
            x: Theme.control.padding
            y: Theme.control.padding
            width: parent.width - 2 * Theme.control.padding
            spacing: Theme.control.spacing

            Row {
                id: header
                width: parent.width
                spacing: Theme.control.padding

                // ticket c14: a double click on the cover or the texts goes to the shown player's app. One handler for
                // the row (a ClippingRectangle's children get no pointer events); the pills have their own double
                // click for their player, and nested TapHandlers both fire, so a tap on them is skipped here.
                TapHandler {
                    onDoubleTapped: eventPoint => {
                        const inPills = pills.visible && pills.contains(pills.mapFromItem(header, eventPoint.position));
                        if (!inPills)
                            root.goToApp(root.player);
                    }
                }

                CoverArt {
                    id: cover
                    size: Theme.media.popupCover
                    source: root.player?.trackArtUrl ?? ""

                    HoverHandler {
                        id: coverHover
                    }

                    HoverHint {
                        delay: Theme.media.keyHintDelay
                        target: cover
                        hovered: coverHover.hovered
                        text: "Enter: go to the app (or double click)\n↑ ↓: player volume\nEsc: close"
                    }
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
                        id: pills
                        width: parent.width
                        visible: Media.players.length > 1
                        spacing: Theme.spacing.sm

                        HoverHandler {
                            id: pillsHover
                        }

                        HoverHint {
                            delay: Theme.media.keyHintDelay
                            target: pills
                            hovered: pillsHover.hovered
                            text: "Next / previous player: Tab / Shift+Tab"
                        }

                        Repeater {
                            model: Media.players

                            Pill {
                                required property MprisPlayer modelData
                                width: Math.min(implicitWidth, parent.width)
                                text: Media.label(modelData)
                                active: modelData === root.player
                                onClicked: Media.select(modelData)
                                onDoubleClicked: root.goToApp(modelData) // picked by the first click
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

                HoverHandler {
                    id: seekHover
                }

                HoverHint {
                    delay: Theme.media.keyHintDelay
                    target: seekSlider
                    hovered: seekHover.hovered
                    text: "Seek 10 s: ← / →"
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.control.spacing

                Pill {
                    id: previousButton
                    width: Theme.media.popupButtonWidth
                    fontSize: Theme.font.sizeLarge
                    text: Logic.ICONS.previous
                    enabled: root.player?.canGoPrevious ?? false
                    onClicked: root.player?.previous()

                    HoverHandler {
                        id: previousHover
                    }

                    HoverHint {
                        delay: Theme.media.keyHintDelay
                        target: previousButton
                        hovered: previousHover.hovered
                        text: "Previous track: Shift+← or ,"
                    }
                }

                Pill {
                    id: playButton
                    width: Theme.media.popupButtonWidth
                    fontSize: Theme.font.sizeLarge
                    active: true
                    text: Logic.playIcon(root.player?.isPlaying ?? false)
                    enabled: root.player?.canTogglePlaying ?? false
                    onClicked: root.player?.togglePlaying()

                    HoverHandler {
                        id: playHover
                    }

                    HoverHint {
                        delay: Theme.media.keyHintDelay
                        target: playButton
                        hovered: playHover.hovered
                        text: "Play / pause: Space"
                    }
                }

                Pill {
                    id: nextButton
                    width: Theme.media.popupButtonWidth
                    fontSize: Theme.font.sizeLarge
                    text: Logic.ICONS.next
                    enabled: root.player?.canGoNext ?? false
                    onClicked: root.player?.next()

                    HoverHandler {
                        id: nextHover
                    }

                    HoverHint {
                        delay: Theme.media.keyHintDelay
                        target: nextButton
                        hovered: nextHover.hovered
                        text: "Next track: Shift+→ or ."
                    }
                }
            }
        }
    }
}
