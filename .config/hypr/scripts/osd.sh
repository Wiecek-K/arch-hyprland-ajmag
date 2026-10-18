#!/bin/bash
# Sourced by volume.sh and brightness.sh: Ajmashell's OSD over IPC (ticket 15, ADR 0008).
# show_osd volume | show_osd brightness <percent>
# False when the shell is not running or has no `osd` target (it prints "Target not found.", exit 0).
# Nothing else shows the level then: there is no other notification server since ticket 23.
show_osd() {
    local out
    out=$(qs -c ajmashell ipc call osd "$@" 2>&1) && [[ -z "$out" ]]
}
