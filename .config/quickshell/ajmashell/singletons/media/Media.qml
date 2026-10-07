// Media — the MPRIS player shown by every Bar's media island and popup (ticket 17), one for all screens,
// so a player picked in the popup is the one on every monitor. Choice rules: media.mjs `pick`.
// Own implementation; idea after serpantinum src/quickshell/singletons/audio/MprisController.qml:
// https://github.com/ilyamiro/serpantinum@67ee7053f2a555684e73a39a795db60750260d8d

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "media.mjs" as Logic

Singleton {
    id: root

    // bus name picked in the popup; wins while that player is around (a restarted Spotify keeps its name)
    property string chosen: ""
    // bus name shown so far; kept while nothing plays (no jump to another player on pause)
    property string current: ""

    readonly property list<MprisPlayer> players: Logic.candidates(Mpris.players.values)
    readonly property MprisPlayer player: Logic.pick(Mpris.players.values, { chosen: chosen, current: current })

    // later, not in the handler: `player` reads `current`, so a direct write is a binding loop
    onPlayerChanged: Qt.callLater(() => current = player?.dbusName ?? "")

    function select(p: MprisPlayer): void {
        chosen = p?.dbusName ?? "";
    }

    function label(p: MprisPlayer): string {
        return p ? Logic.label(p, players) : "";
    }
}
