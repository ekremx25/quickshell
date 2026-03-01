import QtQuick
import QtQuick.Controls
import Qt.labs.platform
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"

ColumnLayout {
    id: root
    spacing: 6

    property string configPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/countdown.json"
    property date selectedDate: new Date()
    property int tickCounter: 0

    // Event list model
    ListModel { id: eventModel }

    // --- SAVE/LOAD LOGIC ---
    Process {
        id: readProc
        command: ["cat", root.configPath]
        property string output: ""
        stdout: SplitParser { onRead: data => readProc.output += data }
        onExited: {
            try {
                var data = JSON.parse(readProc.output);
                if (Array.isArray(data)) {
                    eventModel.clear();
                    for (var i = 0; i < data.length; i++) {
                        eventModel.append(data[i]);
                    }
                }
            } catch(e) {}
        }
    }

    Process {
        id: writeProc
        property string jsonData: ""
        command: ["bash", "-c", "cat > " + root.configPath + " << 'EOF'\n" + jsonData + "\nEOF"]
    }

    Process {
        id: notifyProc
        property string msg: ""
        command: ["notify-send", "-u", "critical", "⏰ Countdown", notifyProc.msg]
    }

    function saveAll() {
        var arr = [];
        for (var i = 0; i < eventModel.count; i++) {
            arr.push(eventModel.get(i));
        }
        writeProc.jsonData = JSON.stringify(arr, null, 2);
        if (writeProc.running) writeProc.running = false;
        writeProc.running = true;
    }

    function addEvent() {
        var title = titleInput.text.trim();
        if (title === "") title = "Event";
        eventModel.append({
            title: title,
            target: root.selectedDate.toISOString(),
            notified: false
        });
        titleInput.text = "";
        saveAll();
    }

    function removeEvent(idx) {
        eventModel.remove(idx);
        saveAll();
    }

    Component.onCompleted: {
        readProc.running = true;
    }

    // --- INPUT SECTION ---
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        TextField {
            id: titleInput
            Layout.fillWidth: true
            placeholderText: "Event Name..."
            color: "#1e1e2e"
            font.pixelSize: 13
            selectByMouse: true
            background: Rectangle {
                color: Qt.rgba(0.9, 0.9, 0.9, 0.9)
                radius: 8
                border.color: parent.activeFocus ? Theme.primary : "transparent"
                border.width: 1
            }
            Keys.onReturnPressed: root.addEvent()
        }

        // SAVE BUTTON
        Rectangle {
            width: 70
            height: 32
            radius: 8
            color: saveMA.containsMouse ? "#a6e3a1" : "#94e2d5"
            Text {
                anchors.centerIn: parent
                text: "Save"
                color: "#1e1e2e"
                font.bold: true
                font.pixelSize: 12
            }
            MouseArea {
                id: saveMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.addEvent()
            }
        }
    }

    // --- DATE DISPLAY ---
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        Text { text: "Date:"; color: "#a6adc8"; font.pixelSize: 12 }

        Text {
            text: root.selectedDate.getDate() + "/" + (root.selectedDate.getMonth() + 1) + "/" + root.selectedDate.getFullYear()
            color: "#cdd6f4"
            font.bold: true
            font.pixelSize: 13
        }
    }

    // --- TIME PICKER ---
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        Text { text: "Time:"; color: "#a6adc8"; font.pixelSize: 13 }

        // --- CUSTOM HOUR INPUT ---
        RowLayout {
            spacing: 4

            // Hour minus button
            Rectangle {
                width: 32; height: 34; radius: 6
                color: hourMinusMA.containsMouse ? "#45475a" : "#313244"
                Text { anchors.centerIn: parent; text: "−"; color: "#cdd6f4"; font.pixelSize: 16; font.bold: true }
                MouseArea {
                    id: hourMinusMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var h = root.selectedDate.getHours();
                        h = (h - 1 + 24) % 24;
                        var d = new Date(root.selectedDate); d.setHours(h); root.selectedDate = d;
                        hourInput.text = (h < 10 ? "0" : "") + h;
                    }
                }
            }

            // Hour text input
            Rectangle {
                width: 48; height: 34; radius: 6
                color: Qt.rgba(0.9, 0.9, 0.9, 0.9)
                TextInput {
                    id: hourInput
                    anchors.fill: parent
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                    color: "#1e1e2e"
                    font.pixelSize: 16
                    font.bold: true
                    selectByMouse: true
                    maximumLength: 2
                    validator: IntValidator { bottom: 0; top: 23 }
                    inputMethodHints: Qt.ImhDigitsOnly
                    text: {
                        var h = root.selectedDate.getHours();
                        return (h < 10 ? "0" : "") + h;
                    }
                    onEditingFinished: {
                        var val = parseInt(text);
                        if (!isNaN(val) && val >= 0 && val <= 23) {
                            var d = new Date(root.selectedDate); d.setHours(val); root.selectedDate = d;
                            text = (val < 10 ? "0" : "") + val;
                        } else {
                            var h = root.selectedDate.getHours();
                            text = (h < 10 ? "0" : "") + h;
                        }
                    }
                    onActiveFocusChanged: {
                        if (activeFocus) selectAll();
                    }
                }
            }

            // Hour plus button
            Rectangle {
                width: 32; height: 34; radius: 6
                color: hourPlusMA.containsMouse ? "#45475a" : "#313244"
                Text { anchors.centerIn: parent; text: "+"; color: "#cdd6f4"; font.pixelSize: 16; font.bold: true }
                MouseArea {
                    id: hourPlusMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var h = root.selectedDate.getHours();
                        h = (h + 1) % 24;
                        var d = new Date(root.selectedDate); d.setHours(h); root.selectedDate = d;
                        hourInput.text = (h < 10 ? "0" : "") + h;
                    }
                }
            }
        }

        Text { text: ":"; color: "#cdd6f4"; font.bold: true; font.pixelSize: 16 }

        // --- CUSTOM MINUTE INPUT ---
        RowLayout {
            spacing: 4

            // Minute minus button
            Rectangle {
                width: 32; height: 34; radius: 6
                color: minMinusMA.containsMouse ? "#45475a" : "#313244"
                Text { anchors.centerIn: parent; text: "−"; color: "#cdd6f4"; font.pixelSize: 16; font.bold: true }
                MouseArea {
                    id: minMinusMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var m = root.selectedDate.getMinutes();
                        m = (m - 1 + 60) % 60;
                        var d = new Date(root.selectedDate); d.setMinutes(m); root.selectedDate = d;
                        minInput.text = (m < 10 ? "0" : "") + m;
                    }
                }
            }

            // Minute text input
            Rectangle {
                width: 48; height: 34; radius: 6
                color: Qt.rgba(0.9, 0.9, 0.9, 0.9)
                TextInput {
                    id: minInput
                    anchors.fill: parent
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                    color: "#1e1e2e"
                    font.pixelSize: 16
                    font.bold: true
                    selectByMouse: true
                    maximumLength: 2
                    validator: IntValidator { bottom: 0; top: 59 }
                    inputMethodHints: Qt.ImhDigitsOnly
                    text: {
                        var m = root.selectedDate.getMinutes();
                        return (m < 10 ? "0" : "") + m;
                    }
                    onEditingFinished: {
                        var val = parseInt(text);
                        if (!isNaN(val) && val >= 0 && val <= 59) {
                            var d = new Date(root.selectedDate); d.setMinutes(val); root.selectedDate = d;
                            text = (val < 10 ? "0" : "") + val;
                        } else {
                            var m = root.selectedDate.getMinutes();
                            text = (m < 10 ? "0" : "") + m;
                        }
                    }
                    onActiveFocusChanged: {
                        if (activeFocus) selectAll();
                    }
                }
            }

            // Minute plus button
            Rectangle {
                width: 32; height: 34; radius: 6
                color: minPlusMA.containsMouse ? "#45475a" : "#313244"
                Text { anchors.centerIn: parent; text: "+"; color: "#cdd6f4"; font.pixelSize: 16; font.bold: true }
                MouseArea {
                    id: minPlusMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var m = root.selectedDate.getMinutes();
                        m = (m + 1) % 60;
                        var d = new Date(root.selectedDate); d.setMinutes(m); root.selectedDate = d;
                        minInput.text = (m < 10 ? "0" : "") + m;
                    }
                }
            }
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.1) }

    // --- MINI CALENDAR GRID ---
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Button {
                text: "◀"
                background: null
                contentItem: Text { text: parent.text; color: Theme.primary; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter }
                onClicked: pickerCal.prevMonth()
            }
            Text {
                text: pickerCal.monthName + " " + pickerCal.displayYear
                color: "#cdd6f4"
                font.bold: true
                font.pixelSize: 13
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
            Button {
                text: "▶"
                background: null
                contentItem: Text { text: parent.text; color: Theme.primary; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter }
                onClicked: pickerCal.nextMonth()
            }
        }

        GridLayout {
            columns: 7
            Layout.alignment: Qt.AlignHCenter
            columnSpacing: 2
            rowSpacing: 2

            Repeater {
                model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                Text {
                    text: modelData
                    color: "#a6adc8"
                    font.pixelSize: 10
                    font.bold: true
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            Repeater {
                model: pickerCal.days
                Rectangle {
                    width: 28; height: 28; radius: 14
                    property bool isSelected: modelData.inMonth && modelData.day === root.selectedDate.getDate() && pickerCal.displayMonth === root.selectedDate.getMonth() && pickerCal.displayYear === root.selectedDate.getFullYear()
                    color: isSelected ? Theme.calendarColor : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: modelData.day
                        color: parent.isSelected ? "#1e1e2e" : (modelData.inMonth ? "#cdd6f4" : "#585b70")
                        font.pixelSize: 11
                        font.bold: parent.isSelected
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: modelData.inMonth
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var newDate = new Date(root.selectedDate);
                            newDate.setFullYear(pickerCal.displayYear);
                            newDate.setMonth(pickerCal.displayMonth);
                            newDate.setDate(modelData.day);
                            root.selectedDate = newDate;
                        }
                    }
                }
            }
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.1) }

    // --- SAVED EVENTS LIST ---
    Text {
        text: eventModel.count > 0 ? "Events (" + eventModel.count + ")" : "No events yet"
        color: "#a6adc8"
        font.pixelSize: 11
        font.bold: true
        Layout.alignment: Qt.AlignHCenter
    }

    ListView {
        id: eventListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 60
        model: eventModel
        clip: true
        spacing: 4

        delegate: Rectangle {
            width: eventListView.width
            height: 40
            radius: 8
            color: Qt.rgba(1,1,1,0.05)
            border.color: {
                var diff = new Date(model.target) - new Date();
                return diff <= 0 ? "#f38ba8" : Qt.rgba(1,1,1,0.1);
            }
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                // Event title
                Text {
                    text: model.title || "Event"
                    color: "#cdd6f4"
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Countdown text
                Text {
                    id: countdownLabel
                    color: {
                        var _tick = root.tickCounter; // force re-eval on tick
                        var diff = new Date(model.target) - new Date();
                        return diff <= 0 ? "#f38ba8" : "#a6e3a1";
                    }
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"

                    property var targetDate: new Date(model.target)
                    text: {
                        var _tick = root.tickCounter; // force re-eval on tick
                        var now = new Date();
                        var diff = targetDate - now;
                        if (diff <= 0) return "Done!";
                        var days = Math.floor(diff / 86400000);
                        var hours = Math.floor((diff % 86400000) / 3600000);
                        var mins = Math.floor((diff % 3600000) / 60000);
                        var secs = Math.floor((diff % 60000) / 1000);
                        if (days > 0) return days + "d " + hours + "h";
                        if (hours > 0) return hours + "h " + mins + "m";
                        return mins + "m " + secs + "s";
                    }
                }

                // Delete button
                Text {
                    text: "✕"
                    color: delMA.containsMouse ? "#f38ba8" : "#6c7086"
                    font.pixelSize: 14
                    MouseArea {
                        id: delMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.removeEvent(index)
                    }
                }
            }
        }
    }

    // --- CALENDAR LOGIC ---
    QtObject {
        id: pickerCal
        property date refDate: new Date()
        property int displayYear: refDate.getFullYear()
        property int displayMonth: refDate.getMonth()
        property string monthName: ""
        property var days: []
        property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

        function prevMonth() {
            if (displayMonth === 0) { displayMonth = 11; displayYear--; } else { displayMonth--; }
            rebuild();
        }
        function nextMonth() {
            if (displayMonth === 11) { displayMonth = 0; displayYear++; } else { displayMonth++; }
            rebuild();
        }
        function rebuild() {
            monthName = monthNames[displayMonth];
            var result = [];
            var firstDay = new Date(displayYear, displayMonth, 1).getDay();
            if (firstDay === 0) firstDay = 7;
            var daysInMonth = new Date(displayYear, displayMonth + 1, 0).getDate();
            var daysInPrevMonth = new Date(displayYear, displayMonth, 0).getDate();
            var startOffset = firstDay - 1;
            for (var i = 0; i < startOffset; i++) result.push({ day: daysInPrevMonth - startOffset + i + 1, inMonth: false });
            for (var j = 1; j <= daysInMonth; j++) result.push({ day: j, inMonth: true });
            var remaining = 42 - result.length;
            for (var k = 1; k <= remaining; k++) result.push({ day: k, inMonth: false });
            days = result;
        }
        Component.onCompleted: rebuild()
    }

    // --- TIMER: Update all countdowns + send notification ---
    Timer {
        id: checkTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date();
            // Force re-evaluation of delegate bindings
            for (var i = 0; i < eventModel.count; i++) {
                var ev = eventModel.get(i);
                var diff = new Date(ev.target) - now;
                if (diff <= 0 && !ev.notified) {
                    // Send desktop notification
                    notifyProc.msg = "\"" + (ev.title || "Event") + "\" time's up!";
                    notifyProc.running = false;
                    notifyProc.running = true;
                    eventModel.setProperty(i, "notified", true);
                    saveAll();
                }
            }
            // Increment tick counter to force countdown text re-eval
            root.tickCounter++;
        }
    }
}
