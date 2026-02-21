import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../Widgets"

Rectangle {
    id: dateRoot

    // --- RENK AYARLARI ---
    property color barBgColor: Theme.calendarColor
    property color barTextColor: Theme.background

    property color popupBg: Theme.background
    property color popupText: Theme.text
    property color accentColor: Theme.calendarColor

    // --- DURUM KONTROLÜ ---
    // showFullDate: Artık varsayılan olarak TRUE (her zaman tarih ve saat görünsün)
    property bool showFullDate: true
    property date currentDate: new Date()

    height: 34
    radius: 17
    color: barBgColor

    // GENİŞLİK: İçeriğe göre otomatik ayarla
    // GENİŞLİK: İçeriğe göre otomatik ayarla
    implicitWidth: layout.implicitWidth + 24
    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

    
    // ... (Timer iptal edilebilir veya sadece takvim popup için kullanılabilir)

    // --- BAR İÇERİĞİ ---
    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: ""
            color: "#1e1e2e"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
        }

        Text {
            id: timeText
            // Format: 17:11 • 16 Şub Paz
            text: {
                if (dateRoot.showFullDate) {
                    return Qt.formatTime(dateRoot.currentDate, "HH:mm") + " • " + Qt.formatDate(dateRoot.currentDate, "dd MMM ddd")
                } else {
                    return Qt.formatTime(dateRoot.currentDate, "HH:mm")
                }
            }
            color: "#1e1e2e"
            font.bold: true
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13 // Matches others roughly
        }
    }

    // Saat Güncelleyici
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: dateRoot.currentDate = new Date()
    }

    // Popup Kapatma Zamanlayıcısı
    Timer {
        id: closeTimer
        interval: 300
        repeat: false
        onTriggered: calWindow.visible = false
    }

    // --- FARE ETKİLEŞİMİ ---
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // Üstüne Gelince: Takvimi Aç
        onEntered: {
            closeTimer.stop()
            calWindow.visible = true
        }

        // Üzerinden Gidince: Takvimi Kapat (Timer ile)
        onExited: {
            closeTimer.start()
        }

        // Tıklayınca: Tarih yazısını Genişlet/Daralt (Takvimi etkilemez)
        onClicked: {
            dateRoot.showFullDate = !dateRoot.showFullDate
        }
    }

    // --- TAKVİM PENCERESİ ---
    PanelWindow {
        id: calWindow
        visible: false
        implicitWidth: 320
        implicitHeight: 560
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors {
            top: true
            left: true
        }

        // Position below the calendar button
        margins {
            top: 58
            left: 0
        }

        Rectangle {
            id: bgRect
            anchors.fill: parent
            color: popupBg
            border.color: accentColor
            border.width: 2
            radius: 12

            HoverHandler {
                id: popupHover
                onHoveredChanged: {
                    if (hovered) closeTimer.stop()
                    else closeTimer.start()
                }
            }

            // Click blocker - sits behind children so they get events first
            MouseArea {
                anchors.fill: parent
                z: -1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                // TAB BAR
                TabBar {
                    id: navBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    currentIndex: viewStack.currentIndex

                    background: Rectangle { color: "transparent" }

                    component MyTabButton: TabButton {
                        property string iconChar
                        background: Rectangle {
                            color: parent.checked ? Qt.rgba(1,1,1,0.1) : "transparent"
                            radius: 5
                        }
                        contentItem: Text {
                            text: parent.iconChar
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: parent.checked ? accentColor : popupText
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: viewStack.currentIndex = TabBar.index
                    }

                    MyTabButton { iconChar: "" } // Calendar
                    MyTabButton { iconChar: "" } // Countdown

                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.1) }

                // CONTENT STACK
                StackLayout {
                    id: viewStack
                    currentIndex: navBar.currentIndex
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // 1. CALENDAR VIEW
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10

                            // BAŞLIK
                            RowLayout {
                                Layout.fillWidth: true

                                Rectangle {
                                    width: 30; height: 30; radius: 15
                                    color: prevMouse.containsMouse ? "#313244" : "transparent"
                                    Text { anchors.centerIn: parent; text: ""; color: accentColor; font.pixelSize: 16 }
                                    MouseArea { id: prevMouse; anchors.fill: parent; hoverEnabled: true; onClicked: calendar.prevMonth() }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: calendar.monthName + " " + calendar.displayYear
                                    color: popupText
                                    font.bold: true; font.pixelSize: 18
                                    font.family: "JetBrainsMono Nerd Font"
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 30; height: 30; radius: 15
                                    color: nextMouse.containsMouse ? "#313244" : "transparent"
                                    Text { anchors.centerIn: parent; text: ""; color: accentColor; font.pixelSize: 16 }
                                    MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true; onClicked: calendar.nextMonth() }
                                }
                            }

                            // GÜN İSİMLERİ
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Repeater {
                                    model: ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
                                    Text {
                                        text: modelData
                                        Layout.preferredWidth: 36
                                        horizontalAlignment: Text.AlignHCenter
                                        color: accentColor
                                        font.bold: true; font.pixelSize: 13
                                    }
                                }
                            }

                            // GÜNLER
                            GridLayout {
                                columns: 7; columnSpacing: 4; rowSpacing: 4
                                Repeater {
                                    model: calendar.days
                                    Rectangle {
                                        width: 36; height: 36; radius: 18
                                        color: modelData.isToday ? accentColor : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.day
                                            color: modelData.isToday ? "#1e1e2e" : (modelData.inMonth ? popupText : "#505050")
                                            font.bold: modelData.isToday
                                            font.family: "JetBrainsMono Nerd Font"
                                        }
                                    }
                                }
                            }
                            
                            Item { Layout.fillHeight: true }
                        }
                    }

                    // 2. COUNTDOWN VIEW
                    Countdown {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }


                }
            }
        }
        onVisibleChanged: if (visible) calendar.toToday()
    }

    QtObject {
        id: calendar
        property var date: new Date()
        property int displayYear: date.getFullYear()
        property int displayMonth: date.getMonth()
        property string monthName: ""
        property var days: []
        property var monthNames: ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]

        function toToday() {
            var now = new Date();
            displayYear = now.getFullYear(); displayMonth = now.getMonth();
            rebuild();
        }
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
            for (var i = 0; i < startOffset; i++) result.push({ day: daysInPrevMonth - startOffset + i + 1, inMonth: false, isToday: false });
            var today = new Date();
            for (var j = 1; j <= daysInMonth; j++) {
                var isToday = (today.getDate() === j && today.getMonth() === displayMonth && today.getFullYear() === displayYear);
                result.push({ day: j, inMonth: true, isToday: isToday });
            }
            var remaining = 42 - result.length;
            for (var k = 1; k <= remaining; k++) result.push({ day: k, inMonth: false, isToday: false });
            days = result;
        }
        Component.onCompleted: rebuild()
    }
}
