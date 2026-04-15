import QtQuick

Item {
    id: backend

    property bool showFullDate: true
    property date currentDate: new Date()
    property int displayYear: currentDate.getFullYear()
    property int displayMonth: currentDate.getMonth()
    property string monthName: ""
    property var days: []
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: backend.currentDate = new Date()
    }

    function rebuild() {
        monthName = monthNames[displayMonth];
        var result = [];
        var firstDay = new Date(displayYear, displayMonth, 1).getDay();
        if (firstDay === 0) firstDay = 7;
        var daysInMonth = new Date(displayYear, displayMonth + 1, 0).getDate();
        var daysInPrevMonth = new Date(displayYear, displayMonth, 0).getDate();
        var startOffset = firstDay - 1;

        for (var i = 0; i < startOffset; i++) {
            result.push({ day: daysInPrevMonth - startOffset + i + 1, inMonth: false, isToday: false });
        }

        var today = new Date();
        for (var j = 1; j <= daysInMonth; j++) {
            result.push({
                day: j,
                inMonth: true,
                isToday: today.getDate() === j && today.getMonth() === displayMonth && today.getFullYear() === displayYear
            });
        }

        var remaining = 42 - result.length;
        for (var k = 1; k <= remaining; k++) {
            result.push({ day: k, inMonth: false, isToday: false });
        }
        days = result;
    }

    function toToday() {
        var now = new Date();
        displayYear = now.getFullYear();
        displayMonth = now.getMonth();
        rebuild();
    }

    function prevMonth() {
        if (displayMonth === 0) {
            displayMonth = 11;
            displayYear--;
        } else {
            displayMonth--;
        }
        rebuild();
    }

    function nextMonth() {
        if (displayMonth === 11) {
            displayMonth = 0;
            displayYear++;
        } else {
            displayMonth++;
        }
        rebuild();
    }

    Component.onCompleted: rebuild()
}
