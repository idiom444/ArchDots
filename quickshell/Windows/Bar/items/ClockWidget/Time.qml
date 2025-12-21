pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    function ordinal(n) {
        const mod100 = n % 100
        if (mod100 >= 11 && mod100 <= 13) return n + "th"
        switch (n % 10) {
        case 1: return n + "st"
        case 2: return n + "nd"
        case 3: return n + "rd"
        default: return n + "th"
        }
    }

    // This is what ClockWidget.qml should display: text: Time.time
    readonly property string time: {
        const d = clock.date        // Date/time value from SystemClock :contentReference[oaicite:1]{index=1}
        const day = d.getDate()

        // No leading zero on hour or seconds:
        //  - "h" not "hh" (no 0-padding)
        //  - "s" not "ss" (no 0-padding) :contentReference[oaicite:2]{index=2}
        const timeStr = Qt.formatDateTime(d, "h:mm:ss AP")
        const datePrefix = Qt.formatDateTime(d, "ddd MMM") // e.g. Sat Dec

        return `${timeStr}  •  ${datePrefix} ${ordinal(day)}` 
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        // If you remove seconds from the format, set this to Minutes for less work. :contentReference[oaicite:3]{index=3}
        // precision: SystemClock.Minutes
    }
}
