import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "."
import "../../../Widgets"

Rectangle {
    id: dateRoot

    // --- COLOR SETTINGS ---
    property color barBgColor: Theme.calendarColor
    property color barTextColor: Theme.background

    property color popupBg: Qt.rgba(28/255, 41/255, 56/255, 0.82)
    property color popupText: "#eef6ff"
    property color accentColor: Theme.calendarColor
    readonly property color glassCard: Qt.rgba(164/255, 226/255, 255/255, 0.09)
    readonly property color glassCardStrong: Qt.rgba(184/255, 239/255, 255/255, 0.14)
    readonly property color glassStroke: Qt.rgba(113/255, 229/255, 255/255, 0.24)
    readonly property color dimText: "#c5d8e8"

    CalendarBackend { id: backend }
    property alias showFullDate: backend.showFullDate
    property alias currentDate: backend.currentDate

    height: 34
    radius: 17
    color: barBgColor

    scale: calMouse.pressed ? 0.93 : (calMouse.containsMouse ? 1.05 : 1.0)

    // WIDTH: Auto-adjust based on content
    implicitWidth: layout.implicitWidth + 24
    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

    
    // ... (Timer can be cancelled or used only for the calendar popup)

    // --- BAR CONTENT ---
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
            // Format: 17:11 • 16 Feb Sun
            text: {
                if (dateRoot.showFullDate) {
                    return Qt.formatTime(dateRoot.currentDate, "HH:mm") + " • " + Qt.formatDate(dateRoot.currentDate, "dd MMM ddd")
                } else {
                    return Qt.formatTime(dateRoot.currentDate, "HH:mm")
                }
            }
            color: "#1e1e2e"
            font.bold: true
            font.family: Theme.fontFamily
            font.pixelSize: 13 // Matches others roughly
        }
    }

    // Popup Close Timer
    Timer {
        id: closeTimer
        interval: 300
        repeat: false
        onTriggered: calWindow.visible = false
    }

    // --- MOUSE INTERACTION ---
    MouseArea {
        id: calMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // On Hover: Open Calendar
        onEntered: {
            closeTimer.stop()
            calWindow.visible = true
        }

        // On Exit: Close Calendar (via Timer)
        onExited: {
            closeTimer.start()
        }

        // On Click: Expand/Collapse date text (does not affect calendar)
        onClicked: {
            dateRoot.showFullDate = !dateRoot.showFullDate
        }
    }

    // --- CALENDAR WINDOW ---
    PopupWindow {
        id: calWindow
        visible: false
        property real panelOpacity: 0.0
        property real panelYOffset: -18
        property real panelScale: 0.97
        Behavior on panelOpacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        Behavior on panelYOffset { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        Behavior on panelScale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        implicitWidth: 400
        implicitHeight: 560
        color: "transparent"

        anchor.window: dateRoot.QsWindow.window
        anchor.onAnchoring: {
            if (!anchor.window) return;
            var win = anchor.window;
            var itemPos = win.contentItem.mapFromItem(dateRoot, 0, 0);
            var desiredX = itemPos.x + (dateRoot.width / 2) - (calWindow.width / 2);
            calWindow.anchor.rect.x = Math.max(5, Math.min(desiredX, win.width - calWindow.width - 5));
            calWindow.anchor.rect.y = win.height + 5;
        }

        function repositionCalendar() {
            // anchor.onAnchoring handles positioning
        }

        Rectangle {
            id: bgRect
            anchors.fill: parent
            opacity: calWindow.panelOpacity
            transform: [
                Translate { y: calWindow.panelYOffset },
                Scale {
                    origin.x: bgRect.width / 2
                    origin.y: 0
                    xScale: calWindow.panelScale
                    yScale: calWindow.panelScale
                }
            ]
            color: popupBg
            border.color: Qt.rgba(115/255, 235/255, 255/255, 0.55)
            border.width: 1
            radius: 16

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(133/255, 224/255, 255/255, 0.12) }
                    GradientStop { position: 0.35; color: Qt.rgba(82/255, 146/255, 173/255, 0.10) }
                    GradientStop { position: 1.0; color: Qt.rgba(37/255, 61/255, 85/255, 0.08) }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.06)
            }

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
                            color: parent.checked ? dateRoot.glassCardStrong : "transparent"
                            border.width: parent.checked ? 1 : 0
                            border.color: parent.checked ? dateRoot.glassStroke : "transparent"
                            radius: 8
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

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.08) }

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

                            // TITLE
                            RowLayout {
                                Layout.fillWidth: true

                                Rectangle {
                                    width: 30; height: 30; radius: 15
                                    color: prevMouse.containsMouse ? dateRoot.glassCardStrong : "transparent"
                                    border.width: prevMouse.containsMouse ? 1 : 0
                                    border.color: prevMouse.containsMouse ? dateRoot.glassStroke : "transparent"
                                    Text { anchors.centerIn: parent; text: ""; color: accentColor; font.pixelSize: 16 }
                                    MouseArea { id: prevMouse; anchors.fill: parent; hoverEnabled: true; onClicked: backend.prevMonth() }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: backend.monthName + " " + backend.displayYear
                                    color: popupText
                                    font.bold: true; font.pixelSize: 18
                                    font.family: Theme.fontFamily
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 30; height: 30; radius: 15
                                    color: nextMouse.containsMouse ? dateRoot.glassCardStrong : "transparent"
                                    border.width: nextMouse.containsMouse ? 1 : 0
                                    border.color: nextMouse.containsMouse ? dateRoot.glassStroke : "transparent"
                                    Text { anchors.centerIn: parent; text: ""; color: accentColor; font.pixelSize: 16 }
                                    MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true; onClicked: backend.nextMonth() }
                                }
                            }

                            // DAY NAMES
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Repeater {
                                    model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                                    Text {
                                        text: modelData
                                        Layout.preferredWidth: 36
                                        horizontalAlignment: Text.AlignHCenter
                                        color: accentColor
                                        font.bold: true; font.pixelSize: 13
                                    }
                                }
                            }

                            // DAYS
                            GridLayout {
                                columns: 7; columnSpacing: 4; rowSpacing: 4
                                Repeater {
                                    model: backend.days
                                    Rectangle {
                                        width: 36; height: 36; radius: 18
                                        color: modelData.isToday ? accentColor : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.day
                                            color: modelData.isToday ? "#1e1e2e" : (modelData.inMonth ? popupText : "#505050")
                                            font.bold: modelData.isToday
                                            font.family: Theme.fontFamily
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
        onVisibleChanged: {
            if (visible) {
                backend.toToday()
                repositionCalendar()
                calWindow.panelOpacity = 0.0
                calWindow.panelYOffset = -22
                calWindow.panelScale = 0.965
                Qt.callLater(function() {
                    calWindow.panelOpacity = 1.0
                    calWindow.panelYOffset = 0
                    calWindow.panelScale = 1.0
                })
            } else {
                calWindow.panelOpacity = 0.0
                calWindow.panelYOffset = -14
                calWindow.panelScale = 0.985
            }
        }

        onWidthChanged: if (visible) repositionCalendar()
        onHeightChanged: if (visible) repositionCalendar()
    }

    onWidthChanged: if (calWindow.visible) calWindow.repositionCalendar()
    onHeightChanged: if (calWindow.visible) calWindow.repositionCalendar()

}
