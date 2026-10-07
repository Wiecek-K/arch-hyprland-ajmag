// OSD (ticket 15, CONTEXT.md): the volume and brightness keys show the new level for a moment at the bottom
// centre of the focused monitor, then it fades out. Replaces the notify-send popups of volume.sh / brightness.sh:
// the scripts call this over IPC while Ajmashell runs (keys only — no OSD for the Bar's wheel or the Centrum's
// sliders; user, 2026-10-07) and fall back to notify-send for Waybar + swaync.
// IPC: qs -c ajmashell ipc call osd volume | osd brightness <percent>
// Volume is read live from the default PipeWire output (it may update a moment after the call);
// brightness comes from the script (sysfs sends no change events).
// Own implementation; idea of an IPC-triggered overlay that hides on a timer after end-4's OSD
// (research B08 §4.3, ii/modules/waffle/onScreenDisplay/WaffleOSD.qml in https://github.com/end-4/dots-hyprland,
// GPL-3.0, idea only). Look: the Centrum's ControlSlider in a Bar island.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.control
import qs.singletons.theme
import "osd.mjs" as Logic

Scope {
    id: root

    property string kind: "volume" // or "brightness"
    property int brightness: 0
    property bool open: false
    property string screenName: ""
    // 0 = hidden, 1 = shown; the window stays mapped while it fades out
    property real shown: open ? 1 : 0

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var view: kind === "brightness" ? Logic.brightnessView(brightness) : Logic.volumeView(sink?.audio ? {
        volume: sink.audio.volume,
        muted: sink.audio.muted,
        formFactor: sink.properties["device.form-factor"] ?? ""
    } : null)

    function show(what: string): void {
        kind = what;
        if (!open)
            screenName = Hyprland.focusedMonitor?.name ?? "";
        open = true;
        hideTimer.restart();
    }

    Behavior on shown {
        NumberAnimation {
            duration: Theme.osd.fade
        }
    }

    // without a tracker PwNodeAudio and properties stay empty
    PwObjectTracker {
        objects: [root.sink]
    }

    Timer {
        id: hideTimer
        interval: Theme.osd.timeout
        onTriggered: root.open = false
    }

    IpcHandler {
        target: "osd"

        function volume(): void {
            root.show("volume");
        }

        function brightness(percent: int): void {
            root.brightness = percent;
            root.show("brightness");
        }
    }

    // Created once at startup and only hidden (keys repeat fast; no window built per press).
    LazyLoader {
        active: true

        // qmltypes mark PanelWindow uncreatable; Quickshell substitutes the Wayland implementation at runtime
        PanelWindow { // qmllint disable uncreatable-type
            visible: root.shown > 0
            screen: Quickshell.screens.find(s => s.name === root.screenName) ?? null
            anchors.bottom: true
            margins.bottom: Theme.osd.marginBottom // qmllint disable unqualified unresolved-type
            implicitWidth: Theme.osd.width
            implicitHeight: box.height
            color: Theme.transparent // the island has rounded ends
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "ajmashell-osd"
            // never takes the keyboard (memory: popups never steal focus) and lets clicks through
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            Rectangle {
                id: box

                width: parent.width
                height: slider.implicitHeight + 2 * Theme.osd.padding
                radius: height / 2
                color: Theme.osd.background
                opacity: root.shown

                ControlSlider {
                    id: slider

                    anchors.fill: parent
                    anchors.margins: Theme.osd.padding
                    implicitHeight: Theme.osd.sliderHeight
                    iconClickable: false
                    position: root.view.position
                    icon: root.view.icon
                    text: root.view.text
                    muted: root.view.muted
                }
            }
        }
    }
}
