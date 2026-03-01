import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"
import "../../../Services" as S

// Toast Popup for new notifications
PanelWindow {
    id: root
    
    // Ensure transparent background for rounded corners
    color: "transparent"

    // Ensure it's above the bar
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "toast-notification"

    // APPEARANCE
    implicitWidth: mainRect.width
    implicitHeight: mainRect.height
    
    // Position: Dynamic based on settings
    anchors {
        top: notifService.popupPosition === 1 || notifService.popupPosition === 2 || notifService.popupPosition === 3
        bottom: notifService.popupPosition === 4 || notifService.popupPosition === 5 || notifService.popupPosition === 6
        left: notifService.popupPosition === 2 || notifService.popupPosition === 6
        right: notifService.popupPosition === 1 || notifService.popupPosition === 5
    }
    margins {
        top: 60
        bottom: 60
        left: 20
        right: 20
    }



    // Starts hidden
    visible: false
    exclusionMode: ExclusionMode.Ignore



    property var notifService: S.Notifications
    property var currentNotif: null

    // --- LOGIC ---

    // Watch for changes in the notification list
    Connections {
        target: notifService
        function onNotificationsChanged() {
            // If we have notifications, check the latest one
            if (notifService.notifications.length > 0) {
                var latest = notifService.notifications[0];
                
                // If it's a new notification (different ID or timestamp from what we showed last)
                // We use ID if available, or just compare summary/body if needed.
                // Simpler: Just show the top one if it's not closed.
                // AND CHECK DND
                if (!latest.closed && !notifService.dnd) {
                    currentNotif = latest;
                    root.visible = true;
                    hideTimer.restart(); // Restart timer
                }
            }
        }
    }

    // Timer to auto-hide after displayDuration
    Timer {
        id: hideTimer
        interval: root.notifService.displayDuration
        repeat: false
        onTriggered: {
            root.visible = false;
        }
    }

    // --- UI ---
    Rectangle {
        id: mainRect
        width: 320
        height: Math.min(content.implicitHeight + 24, 200)
        color: Theme.background
        radius: Theme.radius
        border.width: 1
        border.color: Theme.surface

        // Tıklayınca ilgili pencereye git
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            z: 1
            onClicked: {
                if (currentNotif && currentNotif.appName) {
                    notifService.focusApp(currentNotif.appName);
                }
                root.visible = false;
            }
        }

        // Close Button (Top Right)
        Text {
            anchors { top: parent.top; right: parent.right; margins: 8 }
            text: ""
            font.family: "JetBrainsMono Nerd Font"
            color: Theme.subtext
            z: 10
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.visible = false
            }
        }

        RowLayout {
            id: content
            anchors { left: parent.left; top: parent.top; right: parent.right; margins: 12 }
            spacing: 12

            // Icon
            Rectangle {
                width: 40; height: 40; radius: 10
                color: Theme.base
                clip: true

                Image {
                    anchors.fill: parent
                    source: (currentNotif && currentNotif.appIcon) ? currentNotif.appIcon : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: source != ""
                }
                
                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                    color: Theme.text
                    visible: !((currentNotif && currentNotif.appIcon) && currentNotif.appIcon != "")
                }
            }

            // Text Content
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: currentNotif ? currentNotif.appName : "System"
                    font.bold: true
                    font.pixelSize: 11
                    color: Theme.subtext
                }

                Text {
                    text: currentNotif ? (notifService.privacyMode ? "New notification" : currentNotif.summary) : ""
                    font.bold: true
                    font.pixelSize: 13
                    color: Theme.text
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    text: currentNotif ? (notifService.privacyMode ? "Content hidden" : currentNotif.body) : ""
                    font.pixelSize: 12
                    color: Theme.subtext
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    maximumLineCount: notifService.compactMode ? 1 : 3
                    elide: Text.ElideRight
                }
            }
        }
        
        // Progress Bar (Timer Indicator) - Optional but nice
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 2
            radius: 1
            color: Theme.primary
            width: parent.width * (hideTimer.running ? (1 - (hideTimer.interval - hideTimer.time) / hideTimer.interval) : 0)
            // Can't easily access timer remaining time in QML Timer without custom property hacks.
            // Let's perform a simple animation instead.
            visible: false 
        }
        
        // Simple animation for the progress bar
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left }
            height: 3
            radius: 1.5
            color: Theme.primary
            width: root.visible ? parent.width : 0
            
            Behavior on width {
                enabled: root.visible
                NumberAnimation {
                    duration: root.notifService.displayDuration
                    easing.type: Easing.Linear
                }
            }
            
            // Reset width when hidden
            onWidthChanged: {
                if (!root.visible) width = 0;
            }
        }
    }
}
