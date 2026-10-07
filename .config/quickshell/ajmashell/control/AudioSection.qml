// AudioSection — volume of the default output or input, the device to use and the volume of each app
// (ticket 14, B10 §1), like pavucontrol's tabs in one column. Used by the Centrum sterowania (output) and by
// the audio popup under the Bar's volume islands (output or input; user, 2026-10-07).
// The device rows set PipeWire's preferred default; WirePlumber makes it the default (B10 §1.1).
// Own implementation; logic in control.mjs, icons and percent from the Bar's audio.mjs.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.orbit
import qs.singletons.theme
import "control.mjs" as Logic
import "../bar/audio.mjs" as Audio

Column {
    id: root

    property bool microphone: false
    property bool active: false // read the node list only while shown
    property bool showSlider: true
    property bool showDevices: true
    property bool showStreams: true

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
    readonly property var devices: showDevices ? Logic.audioDevices(nodes, microphone) : []
    readonly property var streams: showStreams ? Logic.audioStreams(nodes, microphone) : []

    spacing: Theme.spacing.md

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

    ControlSlider {
        visible: root.showSlider
        width: parent.width
        position: Logic.volumePosition(root.node?.audio?.volume)
        muted: root.node?.audio?.muted ?? false
        icon: root.iconOf(root.node?.audio ?? null, root.node?.properties["device.form-factor"] ?? "")
        text: root.node?.audio ? Audio.percent(root.node.audio.volume) + "%" : "--"
        onMoved: position => root.setVolume(root.node?.audio ?? null, position)
        onIconClicked: {
            if (root.node?.audio)
                root.node.audio.muted = !root.node.audio.muted;
        }
    }

    OrbitText {
        visible: root.devices.length > 1
        text: root.microphone ? "Input device" : "Output device"
        font.pixelSize: Theme.font.sizeSmall
        color: Theme.control.subtext
    }

    Repeater {
        model: root.devices.length > 1 ? root.devices : [] // one device: nothing to choose

        Rectangle {
            id: device

            required property var modelData
            readonly property bool chosen: modelData.node === root.node

            width: root.width
            height: Theme.control.itemHeight
            radius: height / 2
            color: chosen ? Theme.control.fill : deviceHover.hovered ? Theme.control.hover : Theme.transparent

            OrbitText {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing.lg
                anchors.rightMargin: Theme.spacing.lg
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.font.sizeSmall
                color: device.chosen ? Theme.control.fillText : Theme.control.text
                text: Logic.deviceLabel(device.modelData)
            }

            HoverHandler {
                id: deviceHover
            }

            TapHandler {
                onTapped: {
                    if (root.microphone)
                        Pipewire.preferredDefaultAudioSource = device.modelData.node;
                    else
                        Pipewire.preferredDefaultAudioSink = device.modelData.node;
                }
            }
        }
    }

    OrbitText {
        visible: root.streams.length > 0
        text: root.microphone ? "Recording apps" : "Apps"
        font.pixelSize: Theme.font.sizeSmall
        color: Theme.control.subtext
    }

    Repeater {
        model: root.streams

        Column {
            id: stream

            required property var modelData
            readonly property var names: Logic.streamText(modelData)
            readonly property PwNodeAudio audio: modelData.node.audio

            width: root.width
            spacing: Theme.spacing.xs

            OrbitText {
                width: parent.width
                font.pixelSize: Theme.font.sizeSmall
                text: stream.names.detail ? stream.names.label + " · " + stream.names.detail : stream.names.label
            }

            ControlSlider {
                width: parent.width
                position: Logic.volumePosition(stream.audio?.volume)
                muted: stream.audio?.muted ?? false
                icon: root.iconOf(stream.audio, "")
                text: stream.audio ? Audio.percent(stream.audio.volume) + "%" : "--"
                onMoved: position => root.setVolume(stream.audio, position)
                onIconClicked: {
                    if (stream.audio)
                        stream.audio.muted = !stream.audio.muted;
                }
            }
        }
    }
}
