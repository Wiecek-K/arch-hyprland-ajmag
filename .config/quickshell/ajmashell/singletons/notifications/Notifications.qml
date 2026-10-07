// Notifications — the shell's notification server (replaces swaync while Ajmashell runs, ticket 10):
// history in memory for the bell's count and the Centrum powiadomień (tickets 14, 16), kept grouped per app,
// and the model of the popups shown by notifications/NotificationPopups.qml.
// Adapted from serpantinum src/quickshell/notifications/NotificationManager.qml:
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// Copyright (C) 2026 Illia Miroshnichenko — AGPL-3.0-or-later
// Changes: no 100 ms filter (every notification counts; README 2026-09-26), no startup grace timer
// (lastGeneration says which ones came back after a reload), no grouping, no read state,
// no app resolving via DesktopEntries; history only in memory (no history on disk), capped;
// transient notifications popup only; popups replaced by x-canonical-private-synchronous;
// replaced notifications (same id) update their entry and show their popup again;
// the D-Bus id is the uid; silent mode (DND) as a plain property saved in ~/.local/state/ajmashell/notifications.json;
// grouping per app as runs of the history model (no separate group objects); logic in notifications.mjs.
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "notifications.mjs" as Logic

Singleton {
    id: root

    // grouped per app (appKey): groups by their newest entry, newest first inside a group (ticket 16).
    // roles: uid, appName, appKey, arrival, summary, body, icon, urgency, actions (identifier, text), progress (-1 = none)
    readonly property alias history: historyModel
    // newest first; history roles + timeout (ms, 0 = until clicked), syncKey, generation (bumped on update)
    readonly property alias popups: popupsModel
    readonly property int count: historyModel.count
    // appKey → entries, for the group headers in the Centrum
    readonly property var groupCounts: {
        historyModel.count; // re-count on every insert / remove
        return Logic.groupCounts(roleValues(historyModel, "appKey"));
    }
    // Silent mode (DND): right click on the bell or the switch in the Centrum. Notifications still reach the
    // history and the count; only critical ones pop up. Saved, so a restart keeps it (ticket 16).
    property bool silent: false
    property int arrivals: 0 // arrival number of the newest entry: the history limit drops the oldest one

    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.local/state/ajmashell/notifications.json"
        printErrors: false // missing until silent mode is first switched: that means off
        onLoaded: root.silent = Logic.parseState(text()).silent
    }

    // uid → Notification; only notifications still tracked by the server
    property var live: ({})

    ListModel {
        id: historyModel
    }

    ListModel {
        id: popupsModel
    }

    function indexOf(model, uid: int): int {
        for (let i = 0; i < model.count; i++)
            if (model.get(i).uid === uid)
                return i;
        return -1;
    }

    function roleValues(model, role: string): var {
        const list = [];
        for (let i = 0; i < model.count; i++)
            list.push(model.get(i)[role]);
        return list;
    }

    function entry(n: Notification): var {
        return {
            uid: n.id,
            appName: n.appName,
            appKey: Logic.groupKey(n.appName),
            actions: Logic.actionButtons(Array.from(n.actions).map(a => ({ identifier: a.identifier, text: a.text }))), // qmllint disable unresolved-type
            progress: Logic.progressValue(n.hints),
            summary: n.summary,
            body: n.body,
            icon: Logic.iconSource(n.image || n.appIcon),
            urgency: n.urgency
        };
    }

    function showPopup(n: Notification): void {
        const key = Logic.syncKey(n.hints);
        // from the end, so the indexes stay valid; a transient one is gone with its popup
        for (const index of Logic.replacedPopups(roleValues(popupsModel, "syncKey"), key).reverse()) {
            const old = root.live[popupsModel.get(index).uid];
            popupsModel.remove(index, 1);
            if (old?.transient)
                old.expire();
        }
        popupsModel.insert(0, Object.assign(entry(n), {
            timeout: Logic.popupTimeout(n),
            syncKey: key,
            generation: 0
        }));
    }

    // a notification sent again with the same id (replaces_id): Quickshell updates it in place
    function update(n: Notification): void {
        const data = entry(n);
        const h = indexOf(historyModel, n.id);
        if (h >= 0)
            historyModel.set(h, Object.assign({}, data, { arrival: historyModel.get(h).arrival }));
        const p = indexOf(popupsModel, n.id);
        if (p >= 0) {
            popupsModel.set(p, Object.assign(data, {
                timeout: Logic.popupTimeout(n),
                generation: popupsModel.get(p).generation + 1
            }));
        } else if (Logic.popupAllowed({ silent, urgency: n.urgency })) {
            showPopup(n);
        }
    }

    function forget(uid: int): void {
        delete root.live[uid];
        const h = indexOf(historyModel, uid);
        if (h >= 0)
            historyModel.remove(h, 1);
        removePopup(uid);
    }

    // the popup goes; the notification stays in the history (a transient one has no history: it expires)
    function removePopup(uid: int): void {
        const p = indexOf(popupsModel, uid);
        if (p >= 0)
            popupsModel.remove(p, 1);
        const n = root.live[uid];
        if (n?.transient && indexOf(historyModel, uid) < 0)
            n.expire();
    }

    // a new entry goes on top of its app's group, and the group moves to the top (ticket 16)
    function addToHistory(n: Notification): void {
        const data = Object.assign(entry(n), { arrival: ++root.arrivals });
        const block = Logic.groupBlock(roleValues(historyModel, "appKey"), data.appKey);
        if (block && block.from > 0)
            historyModel.move(block.from, 0, block.count);
        historyModel.insert(0, data);
        for (let i = Logic.overLimit(historyModel.count); i > 0; i--) {
            const index = Logic.oldestIndex(roleValues(historyModel, "arrival"));
            const oldest = historyModel.get(index).uid;
            historyModel.remove(index, 1);
            root.live[oldest]?.dismiss();
        }
    }

    // click on a card: the app's default action when it has one, then the notification is gone;
    // a button under the card: that action (blueman's Confirm / Deny, ticket 16)
    function activate(uid: int, identifier: string): void {
        const n = root.live[uid];
        if (!n) {
            removePopup(uid);
            return;
        }
        const wanted = identifier || "default";
        const action = Array.from(n.actions).find(a => a.identifier === wanted);
        if (action)
            action.invoke(); // dismisses a non-resident notification itself
        if (!root.live[uid])
            return;
        if (action && n.resident)
            removePopup(uid); // resident: stays in the history after its action
        else
            n.dismiss();
    }

    function toggleSilent(): void {
        setSilent(!silent);
    }

    function setSilent(value: bool): void {
        silent = value;
        stateFile.setText(Logic.formatState({ silent }));
        if (!silent)
            return;
        // popups already on screen go too, except critical ones
        for (let i = popupsModel.count - 1; i >= 0; i--)
            if (!Logic.popupAllowed({ silent, urgency: popupsModel.get(i).urgency }))
                removePopup(popupsModel.get(i).uid);
    }

    function clear(): void {
        for (const uid of Object.keys(root.live))
            root.live[uid]?.dismiss(); // closed → forget
        historyModel.clear();
        popupsModel.clear();
    }

    // "Clear" on a group header in the Centrum
    function clearGroup(appKey: string): void {
        const uids = [];
        for (let i = 0; i < historyModel.count; i++)
            if (historyModel.get(i).appKey === appKey)
                uids.push(historyModel.get(i).uid);
        for (const uid of uids) {
            if (root.live[uid])
                root.live[uid].dismiss(); // closed → forget
            else
                forget(uid);
        }
    }

    // qs -c ajmashell ipc call notifications toggleSilent | clear  (pattern from caelestia services/Notifs.qml, research B08)
    IpcHandler {
        target: "notifications"

        function toggleSilent(): void {
            root.toggleSilent();
        }

        function clear(): void {
            root.clear();
        }
    }

    NotificationServer {
        // keepOnReload (default) re-sends the tracked notifications after a hot reload with
        // lastGeneration set; they go back to the history without a popup.
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true;
            const uid = n.id;
            root.live[uid] = n;
            n.closed.connect(() => root.forget(uid));
            // one closure per notification: Qt.callLater merges calls of the same function
            // and none after close: the object is gone, update() would bring its popup back
            const refresh = () => {
                if (root.live[uid])
                    root.update(n);
            };
            n.summaryChanged.connect(() => Qt.callLater(refresh));
            n.bodyChanged.connect(() => Qt.callLater(refresh));
            n.hintsChanged.connect(() => Qt.callLater(refresh)); // progress bar (hint `value`) on every update
            n.actionsChanged.connect(() => Qt.callLater(refresh));

            if (Logic.keptInHistory(n))
                root.addToHistory(n);
            if (!n.lastGeneration && Logic.popupAllowed({ silent: root.silent, urgency: n.urgency }))
                root.showPopup(n);
            else if (!Logic.keptInHistory(n))
                n.expire(); // transient without a popup (silent mode, or from before the reload): nothing to keep
        }
    }
}
