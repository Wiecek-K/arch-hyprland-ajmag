// Notifications — the shell's notification server (replaces swaync while Ajmashell runs, ticket 10):
// history in memory for the bell's count (and later the Notification centre, tickets 14, 16)
// and the model of the popups shown by notifications/NotificationPopups.qml.
// Adapted from serpantinum src/quickshell/notifications/NotificationManager.qml:
// https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
// Copyright (C) 2026 Illia Miroshnichenko — AGPL-3.0-or-later
// Changes: no 100 ms filter (every notification counts; README 2026-09-26), no startup grace timer
// (lastGeneration says which ones came back after a reload), no grouping, no read state,
// no app resolving via DesktopEntries; history only in memory (no history on disk), capped;
// transient notifications popup only; popups replaced by x-canonical-private-synchronous;
// replaced notifications (same id) update their entry and show their popup again;
// the D-Bus id is the uid; silent mode (DND) as a plain property; logic in notifications.mjs.
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

    // newest first; roles: uid, appName, summary, body, icon, urgency
    readonly property alias history: historyModel
    // newest first; history roles + timeout (ms, 0 = until clicked), syncKey, generation (bumped on update)
    readonly property alias popups: popupsModel
    readonly property int count: historyModel.count
    // Silent mode (DND): right click on the bell. Notifications still reach the history and the count;
    // only critical ones pop up. In memory: a restart turns it off (persisting it: ticket 16).
    property bool silent: false

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

    function entry(n: Notification): var {
        return {
            uid: n.id,
            appName: n.appName,
            summary: n.summary,
            body: n.body,
            icon: Logic.iconSource(n.image || n.appIcon),
            urgency: n.urgency
        };
    }

    function showPopup(n: Notification): void {
        const key = Logic.syncKey(n.hints);
        const keys = [];
        for (let i = 0; i < popupsModel.count; i++)
            keys.push(popupsModel.get(i).syncKey);
        // from the end, so the indexes stay valid; a transient one is gone with its popup
        for (const index of Logic.replacedPopups(keys, key).reverse()) {
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
            historyModel.set(h, data);
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

    // click on a popup: the app's default action when it has one, then the notification is gone
    function activate(uid: int): void {
        const n = root.live[uid];
        if (!n) {
            removePopup(uid);
            return;
        }
        const action = Array.from(n.actions).find(a => a.identifier === "default");
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
        silent = !silent;
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

            if (Logic.keptInHistory(n)) {
                historyModel.insert(0, root.entry(n));
                for (let i = Logic.overLimit(historyModel.count); i > 0; i--) {
                    const oldest = historyModel.get(historyModel.count - 1).uid;
                    historyModel.remove(historyModel.count - 1, 1);
                    root.live[oldest]?.dismiss();
                }
            }
            if (!n.lastGeneration && Logic.popupAllowed({ silent: root.silent, urgency: n.urgency }))
                root.showPopup(n);
            else if (!Logic.keptInHistory(n))
                n.expire(); // transient without a popup (silent mode, or from before the reload): nothing to keep
        }
    }
}
