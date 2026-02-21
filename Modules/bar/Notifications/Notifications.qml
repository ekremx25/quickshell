import QtQuick
import QtQuick.Layouts
import Quickshell
// We use the singleton from Services directly or via import
import "../../../Services" as S

// This component is the button in the bar
Rectangle {
    id: root

    // APPEARANCE
    implicitWidth: layout.implicitWidth + 24
    implicitHeight: 30
    radius: 15

    // Connect to the Notifications singleton
    // Note: S.Notifications is the singleton instance
    property var notifService: S.Notifications

    // Logic: Red if critical/urgent? Or just show count.
    // For now: Blue if we have unread/active notifications, Gray/Transparent otherwise?
    // Let's stick to the Volume style: Green/Red or Blue/Gray.
    // Active notifications = Blue (#89b4fa)
    // No notifications = Transparent or Surface color? 
    // Volume uses: #a6e3a1 (Green) for active, #f38ba8 (Red) for muted.
    // Let's use:
    // Active (>0): #fab387 (Peach/Orange) or #f9e2af (Yellow) to stand out? 
    // Let's use #fab387 (Peach) for now.
    // Empty: #45475a (Surface) or transparent? 
    // Let's make it visible always for now, or maybe hide if 0?
    // User probably wants it visible to access history.
    
    // Check if there are active notifications
    property bool hasActive: notifService.activeNotifications.length > 0
    property int count: notifService.activeNotifications.length

    color: hasActive ? "#fab387" : "#45475a"

    Behavior on color { ColorAnimation { duration: 200 } }

    // Main Layout
    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 8

        // --- NOTIFICATION TOGGLE ---
        Item {
            implicitWidth: iconRow.implicitWidth
            implicitHeight: iconRow.implicitHeight
            
            RowLayout {
                id: iconRow
                spacing: 6
                
                // Icon
                Text {
                    text: notifService.dnd ? "" : (hasActive ? "" : "")
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    color: notifService.dnd ? "#f38ba8" : (hasActive ? "#1e1e2e" : "#cdd6f4")
                }

                // Count
                Text {
                    text: count > 0 ? count : ""
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    color: "#1e1e2e"
                    visible: count > 0
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        notifPopup.visible = !notifPopup.visible
                        durPopup.visible = false
                    } else if (mouse.button === Qt.RightButton) {
                        notifService.dnd = !notifService.dnd
                    }
                }
            }
        }

        // Separator
        Rectangle {
            width: 1
            height: 14
            color: hasActive ? "#1e1e2e" : "#6c7086"
            opacity: 0.5
        }

        // --- DURATION CONTROL ---
        Item {
            implicitWidth: durRow.implicitWidth
            implicitHeight: durRow.implicitHeight

            RowLayout {
                id: durRow
                spacing: 2
                
                Text {
                    text: "" // Timer icon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: hasActive ? "#1e1e2e" : "#a6adc8"
                }
                
                Text {
                    text: (notifService.displayDuration / 1000) + "s"
                    font.bold: true
                    font.pixelSize: 12
                    color: hasActive ? "#1e1e2e" : "#cdd6f4"
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                // Wheel to change
                onWheel: (wheel) => {
                    var delta = wheel.angleDelta.y > 0 ? 1000 : -1000;
                    var newVal = notifService.displayDuration + delta;
                    if (newVal >= 1000 && newVal <= 600000) {
                        notifService.displayDuration = newVal;
                    }
                }
                // Click to open popup
                onClicked: {
                    durPopup.visible = !durPopup.visible
                    notifPopup.visible = false
                }
            }
        }
    }

    // POPUPs
    Item {
        id: notifPopup
        visible: false
        
        Loader {
            id: notifPopupLoader
            active: true
            source: "NotificationPopup.qml"
            
            Connections {
                target: S.Notifications
                function onPopupPositionChanged() {
                    notifPopupLoader.active = false
                    Qt.callLater(() => { notifPopupLoader.active = true })
                }
            }
            
            onLoaded: {
                item.visible = Qt.binding(() => notifPopup.visible)
            }
        }
        
        Connections {
            target: notifPopupLoader.item
            ignoreUnknownSignals: true
            function onVisibleChanged() {
                if (notifPopupLoader.item && notifPopupLoader.item.visible !== notifPopup.visible) {
                    notifPopup.visible = notifPopupLoader.item.visible
                }
            }
        }
    }
    
    DurationPopup {
        id: durPopup
        visible: false
    }

    // TOAST


}
