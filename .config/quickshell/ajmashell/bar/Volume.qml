// Volume island — output volume of the default PipeWire sink, like our Waybar "pulseaudio" module
// (~/.config/waybar/Modules) and ~/.config/hypr/scripts/volume.sh.
// Wheel ±5% up to 150%, left click mutes (ticket 08a, user 2026-10-01).
// Right click opens the audio popup: device choice and app volumes in the Orbita's look (ticket 14, user 2026-10-07;
// was pavucontrol).
// With `microphone: true` the same island shows the default source, like Waybar "pulseaudio#microphone" (ticket 08b).
// Own implementation; Pipewire binding like DankMaterialShell quickshell/Services/AudioService.qml
// (PwObjectTracker, form factor from node properties), see audio.mjs:
// https://github.com/AvengeMedia/DankMaterialShell@9dc5b2c5af7d18b7231f425fe0d8fa7243233109

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.control
import qs.singletons.theme
import "audio.mjs" as Logic
import "wheel.mjs" as Wheel

Island {
    id: root

    property bool microphone: false
    readonly property PwNode node: microphone ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
    readonly property PwNodeAudio audio: node?.audio ?? null
    readonly property bool muted: audio?.muted ?? false
    readonly property real volume: audio?.volume ?? 0
    property real wheelRest: 0

    spacing: Theme.spacing.md // Waybar: one space in "{icon} {volume}%"

    // without a tracker PwNodeAudio and properties stay empty
    PwObjectTracker {
        objects: [root.node]
    }

    onClicked: {
        if (audio)
            audio.muted = !audio.muted;
    }

    onRightClicked: popup.toggle()

    onWheelMoved: delta => {
        const step = Wheel.wheel(wheelRest, delta);
        wheelRest = step.rest;
        if (!step.step || !audio)
            return;
        const next = Logic.wheelStep(audio.volume, audio.muted, step.step);
        audio.muted = next.muted;
        audio.volume = next.volume;
    }

    // Fixed-width slots: icon glyphs differ in width, the percent text is always four
    // monospace characters, so nothing moves when the level or mute state changes.
    IconSlot {
        id: icon
        icons: root.microphone ? Logic.MIC_ICONS : Logic.ICONS
        text: root.microphone ? Logic.micIcon({ muted: root.muted }) : Logic.icon({ volume: root.volume, muted: root.muted, formFactor: root.node?.properties["device.form-factor"] })
        color: root.muted ? Theme.bar.muted : Theme.bar.text
    }

    Text {
        anchors.verticalCenter: parent?.verticalCenter
        text: root.audio ? Logic.percentText(root.volume) : "  --"
        font: icon.font
        color: icon.color
    }

    BarTooltip {
        target: root
        hovered: root.hovered && !popup.visible
        text: root.node?.description ?? ""
    }

    AudioPopup {
        id: popup
        source: root
        microphone: root.microphone
    }
}
