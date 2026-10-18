#!/usr/bin/env python3
# Pairs one Bluetooth device for the Orbita (ticket 12) and acts as its BlueZ agent, so a device that
# asks to compare a code (Numeric Comparison) can be confirmed in the Orbita's core.
# BlueZ asks the agent of the D-Bus client that called Device1.Pair(), so this helper calls Pair() itself
# and registers a non-default agent. No default agent runs since ticket 23 (blueman-applet removed), so a pairing
# a device starts has none: pair from the Orbita.
# Own implementation after the BlueZ Agent1 API (doc/org.bluez.Agent.rst); blueman's pairing
# notification (Confirm / Deny) is the model for the flow.
#
# Usage: bt-pair.py <address>
# stdout, one JSON line per event:
#   {"event": "confirm", "passkey": 427746}   same code on the device? answer "yes" or "no" on stdin
#   {"event": "display", "passkey": 123456}   type this code on the device (also "pincode": "0000")
#   {"event": "done"} | {"event": "failed", "error": "<D-Bus error name>" | "pin" | "no-device"}
# stdin: "yes" / "no" (with no question open, "no" cancels); end of input or SIGTERM cancels too (the Orbita
# closed or started another pairing). A D-Bus error before pairing starts is reported as "failed" as well.

import json
import signal
import sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

AGENT_PATH = "/org/ajmashell/orbit_agent"
CAPABILITY = "DisplayYesNo"  # no keyboard: a device that needs a typed PIN is refused


def emit(**event):
    print(json.dumps(event), flush=True)


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class Agent(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, AGENT_PATH)
        self.pending = None  # (reply, error) of the open RequestConfirmation
        self.needs_pin = False
        self.shown = None  # the code on display, sent once although BlueZ repeats DisplayPasskey

    def answer(self, yes):
        if not self.pending:
            return
        reply, error = self.pending
        self.pending = None
        if yes:
            reply()
        else:
            error(Rejected("Rejected by the user"))

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Release(self):
        pass

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        self.needs_pin = True
        raise Rejected("No PIN entry in the Orbita")

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        self.needs_pin = True
        raise Rejected("No passkey entry in the Orbita")

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        if self.shown != pincode:
            self.shown = pincode
            emit(event="display", pincode=str(pincode))

    @dbus.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        if self.shown != int(passkey):
            self.shown = int(passkey)
            emit(event="display", passkey=int(passkey))

    @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="",
                         async_callbacks=("reply", "error"))
    def RequestConfirmation(self, device, passkey, reply, error):
        self.answer(False)
        self.pending = (reply, error)
        emit(event="confirm", passkey=int(passkey))

    # the user clicked Pair in the Orbita for this device: nothing more to ask
    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        pass

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        pass

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Cancel(self):
        self.pending = None


def device_path(bus, address):
    manager = dbus.Interface(bus.get_object("org.bluez", "/"), "org.freedesktop.DBus.ObjectManager")
    for path, interfaces in manager.GetManagedObjects().items():
        device = interfaces.get("org.bluez.Device1")
        if device and str(device.get("Address", "")).upper() == address.upper():
            return path
    return None


def main():
    if len(sys.argv) != 2:
        print("usage: bt-pair.py <address>", file=sys.stderr)
        return 2
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    try:
        return pair(sys.argv[1])
    except dbus.DBusException as err:  # bluetoothd gone, agent refused…: the Orbita must not wait forever
        emit(event="failed", error=err.get_dbus_name() or "dbus")
        return 1


def pair(address):
    bus = dbus.SystemBus()
    loop = GLib.MainLoop()
    path = device_path(bus, address)
    if not path:
        emit(event="failed", error="no-device")
        return 1

    agent = Agent(bus)
    agents = dbus.Interface(bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1")
    agents.RegisterAgent(AGENT_PATH, CAPABILITY)
    try:
        device = dbus.Interface(bus.get_object("org.bluez", path), "org.bluez.Device1")
        result = {"code": 1}

        def done():
            emit(event="done")
            result["code"] = 0
            loop.quit()

        def failed(err):
            emit(event="failed", error="pin" if agent.needs_pin else err.get_dbus_name())
            loop.quit()

        def cancel():
            agent.answer(False)
            try:
                device.CancelPairing()
            except dbus.DBusException:
                pass
            loop.quit()
            return False

        def on_input(source, condition):
            line = source.readline()
            if not line:  # the Orbita closed: stop pairing
                return cancel()
            if line.strip() == "yes":
                agent.answer(True)
            elif agent.pending:
                agent.answer(False)
            else:  # "no" while a code is on display: stop pairing
                try:
                    device.CancelPairing()
                except dbus.DBusException:
                    pass
            return True

        GLib.io_add_watch(sys.stdin, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP, on_input)
        GLib.unix_signal_add(GLib.PRIORITY_HIGH, signal.SIGTERM, cancel)  # the Orbita stops the process
        device.Pair(reply_handler=done, error_handler=failed, timeout=90)
        loop.run()
        return result["code"]
    finally:
        try:
            agents.UnregisterAgent(AGENT_PATH)
        except dbus.DBusException:
            pass


if __name__ == "__main__":
    sys.exit(main())
