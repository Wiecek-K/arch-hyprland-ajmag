// AudioSection — volume of the default output or input, the device to use and the volume of each app
// (ticket 14, B10 §1), like pavucontrol's tabs in one column. Used by the Centrum sterowania (output: slider, device)
// and by the audio popup under the Bar's volume islands (output or input: slider, device, apps; user, 2026-10-07).
// Faza C ticket 17 (UI prototype, user 2026-11-08): the device is one field with the current device (icon, short
// name), a click opens the list (icon circle, short name, what it is, check on the chosen one) — variant C; the apps
// sit on their own card, each with its icon, name and tab title over its slider — variant A. Apps only in the popup:
// in the Centrum they made the panel too crowded. Prototype with all four variants: dotfiles branch
// prototype/ticket-c17-audio-ui.
// The device rows set PipeWire's preferred default; WirePlumber makes it the default (B10 §1.1).
// Own implementation; logic in control.mjs, icons and percent from the Bar's audio.mjs. Ideas only: icon circle and
// check (caelestia-dots/shell modules/nexus/common/AudioDeviceList.qml), app icon lookup and the current-device
// field (end-4/dots-hyprland ii/modules/ii/sidebarRight/volumeMixer/), both GPL-3.0.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.orbit
import qs.singletons.theme
import "control.mjs" as Logic
import "../bar/audio.mjs" as Audio

Column {
    id: root

    property bool microphone: false
    // true while shown: read and track every node (devices, apps). False: only the default node stays tracked,
    // which the slider needs anyway (the Bar's volume islands track it too)
    property bool active: false
    property bool showSlider: true
    property bool showDevices: true
    property bool showStreams: true
    property bool devicesOpen: false // the device list under the field; closed again on each opening

    readonly property PwNode node: microphone ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
    // plain objects for control.mjs; the PwNode rides along
    readonly property var nodes: active ? Pipewire.nodes.values.map(n => ({
                id: n.id,
                name: n.name,
                description: n.description,
                nickname: n.nickname,
                isSink: n.isSink,
                isStream: n.isStream,
                audio: n.audio !== null,
                properties: n.properties,
                node: n
            })) : []
    readonly property var devices: showDevices ? Logic.audioDevices(nodes, microphone).map(d => Object.assign(d, Logic.deviceKind(d, microphone))) : []
    readonly property var streams: showStreams ? Logic.audioStreams(nodes, microphone) : []
    readonly property var current: devices.find(d => d.node === node) ?? null

    spacing: Theme.spacing.md

    onActiveChanged: devicesOpen = false
    // the field hides with one device left; without this the list came back open with the second device
    onDevicesChanged: {
        if (devices.length <= 1)
            devicesOpen = false;
    }

    // without a tracker PwNodeAudio and properties stay empty
    PwObjectTracker {
        objects: root.active ? Pipewire.nodes.values : [root.node]
    }

    function iconOf(audio: PwNodeAudio, formFactor: string): string {
        const muted = audio?.muted ?? false;
        return microphone ? Audio.micIcon({ muted }) : Audio.icon({ volume: audio?.volume ?? 0, muted, formFactor });
    }

    function setVolume(audio: PwNodeAudio, position: real): void {
        if (!audio)
            return;
        audio.muted = false; // moving the level means "I want to hear it"
        audio.volume = Logic.volumeAt(position);
    }

    function toggleMute(audio: PwNodeAudio): void {
        if (audio)
            audio.muted = !audio.muted;
    }

    function percentOf(audio: PwNodeAudio): string {
        return audio ? Audio.percent(audio.volume) + "%" : "--";
    }

    function choose(device: var): void {
        if (microphone)
            Pipewire.preferredDefaultAudioSource = device.node;
        else
            Pipewire.preferredDefaultAudioSink = device.node;
        devicesOpen = false;
    }

    // the first candidate the icon theme has ("" = the note glyph); iconPath(name, true) is "" for a missing name
    function appIcon(properties: var): string {
        for (const name of Logic.appIconCandidates(properties)) {
            for (const icon of [DesktopEntries.heuristicLookup(name)?.icon ?? "", name]) {
                const path = icon ? Quickshell.iconPath(icon, true) : "";
                if (path)
                    return path;
            }
        }
        return "";
    }

    ControlSlider {
        visible: root.showSlider
        width: parent.width
        position: Logic.volumePosition(root.node?.audio?.volume)
        muted: root.node?.audio?.muted ?? false
        icon: root.iconOf(root.node?.audio ?? null, root.node?.properties["device.form-factor"] ?? "")
        text: root.percentOf(root.node?.audio ?? null)
        onMoved: position => root.setVolume(root.node?.audio ?? null, position)
        onIconClicked: root.toggleMute(root.node?.audio ?? null)
    }

    // the current device; a click opens the list (one device: nothing to choose, no field)
    Column {
        visible: root.devices.length > 1
        width: root.width
        spacing: Theme.spacing.sm

        Rectangle {
            width: root.width
            height: Theme.control.fieldHeight
            radius: Theme.radius.lg
            color: fieldHover.hovered ? Theme.control.hover : Theme.control.track

            AudioLine {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacing.md
                anchors.right: fieldArrow.left
                anchors.rightMargin: Theme.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                glyph: root.current?.icon ?? (root.microphone ? Logic.AUDIO_ICON.mic : Logic.AUDIO_ICON.speaker)
                chosen: true
                overline: root.microphone ? "Input" : "Output"
                title: root.current?.title ?? "--"
            }

            OrbitText {
                id: fieldArrow
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing.lg
                anchors.verticalCenter: parent.verticalCenter
                text: root.devicesOpen ? Logic.AUDIO_ICON.open : Logic.AUDIO_ICON.closed
                color: Theme.control.subtext
            }

            HoverHandler {
                id: fieldHover
            }

            TapHandler {
                onTapped: root.devicesOpen = !root.devicesOpen
            }
        }

        Column {
            visible: root.devicesOpen
            width: root.width

            Repeater {
                model: root.devicesOpen ? root.devices : []

                Rectangle {
                    id: device

                    required property var modelData
                    readonly property bool chosen: modelData.node === root.node

                    width: root.width
                    height: Theme.control.deviceHeight
                    radius: Theme.radius.sm
                    color: deviceHover.hovered ? Theme.control.hover : Theme.transparent

                    AudioLine {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacing.md
                        anchors.right: deviceCheck.left
                        anchors.rightMargin: Theme.spacing.md
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: device.modelData.icon
                        chosen: device.chosen
                        title: device.modelData.title
                        subtitle: device.modelData.subtitle
                    }

                    Text {
                        id: deviceCheck
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacing.lg
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: device.chosen ? 1 : 0 // keeps its width, so the names do not move
                        text: Logic.AUDIO_ICON.check
                        font.family: Theme.font.family
                        font.pixelSize: Theme.font.size
                        color: Theme.control.accent
                    }

                    HoverHandler {
                        id: deviceHover
                    }

                    TapHandler {
                        onTapped: root.choose(device.modelData)
                    }
                }
            }
        }
    }

    // apps on their own card
    Rectangle {
        visible: root.streams.length > 0
        width: root.width
        height: apps.implicitHeight + 2 * Theme.spacing.md
        radius: Theme.radius.lg
        color: Theme.control.card

        Column {
            id: apps
            x: Theme.spacing.md
            y: Theme.spacing.md
            width: parent.width - 2 * Theme.spacing.md
            spacing: Theme.spacing.md

            Row {
                spacing: Theme.spacing.md

                Text {
                    text: Logic.AUDIO_ICON.apps
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.size
                    color: Theme.control.accent
                }

                OrbitText {
                    text: root.microphone ? "Recording apps" : "Apps"
                    font.pixelSize: Theme.font.sizeSmall
                    color: Theme.control.subtext
                }
            }

            Repeater {
                model: root.streams

                Column {
                    id: stream

                    required property var modelData
                    readonly property var names: Logic.streamText(modelData)
                    readonly property string iconSource: root.appIcon(modelData.properties)
                    readonly property PwNodeAudio audio: modelData.node.audio

                    width: apps.width
                    spacing: Theme.spacing.sm

                    AudioLine {
                        width: parent.width
                        glyph: Logic.AUDIO_ICON.app
                        iconSource: stream.iconSource
                        circle: false
                        title: stream.names.label
                        subtitle: stream.names.detail
                    }

                    ControlSlider {
                        width: parent.width
                        position: Logic.volumePosition(stream.audio?.volume)
                        muted: stream.audio?.muted ?? false
                        icon: root.iconOf(stream.audio, "")
                        text: root.percentOf(stream.audio)
                        onMoved: position => root.setVolume(stream.audio, position)
                        onIconClicked: root.toggleMute(stream.audio)
                    }
                }
            }
        }
    }
}
