// FadeFast — the short fade of small parts that appear and hide (an icon, the time, the X, a stack edge):
// `Behavior on opacity { FadeFast {} }`. Split out of the Centrum's row and NotificationCard (faza C ticket 03).
// Own implementation.

import QtQuick
import qs.singletons.theme

NumberAnimation {
    duration: Theme.motion.fast
}
