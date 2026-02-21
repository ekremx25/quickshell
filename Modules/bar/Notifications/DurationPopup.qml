import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../../Services" as S

PanelWindow {
    id: root
    
    // Positioned relative to the bar cursor or fixed?
    // Let's make it appear near the mouse or hardcoded near the notification icon.
    // Anchors don't work well for dynamic popups unless we anchor to the bar window which is separate.
    // simpler: anchors { top: true; right: true } with margins matching the item position?
    // Hard to know exact X position of the item in the bar.
    // Let's put it top-right but offset more to the left than the notification popup.
    
    anchors { top: true; right: true }
    margins { top: 60; right: 140 } // Offset to left of NotificationPopup

    implicitWidth: 160
    implicitHeight: 80
    
    color: "transparent"
    visible: false
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property var notifService: S.Notifications

    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e" // Base color
        radius: 12
        border.width: 1
        border.color: "#cdd6f4" // Surface/Text color

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: "Duration (seconds)"
                color: "#a6adc8"
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                width: 100; height: 30
                color: "#313244"
                radius: 5
                
                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.margins: 4
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    
                    text: (root.notifService.displayDuration / 1000).toString()
                    color: "#cdd6f4"
                    font.pixelSize: 14
                    
                    validator: IntValidator { bottom: 1; top: 3600 }
                    
                    onAccepted: {
                        var val = parseInt(text);
                        if (!isNaN(val)) root.notifService.displayDuration = val * 1000;
                        root.visible = false;
                    }
                }
            }
        }
        
        // Close on click outside? Hard with PanelWindow.
        // Add explicit close button?
    }
}
