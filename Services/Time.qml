pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root
    readonly property string day: {
        Qt.formatDateTime(clock.date, "d");
    }
    readonly property string month: {
        Qt.formatDateTime(clock.date, "MMM");
    }
    readonly property string hours: {
        Qt.formatDateTime(clock.date, "hh");
    }
    readonly property string minutes: {
        Qt.formatDateTime(clock.date, "mm");
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
