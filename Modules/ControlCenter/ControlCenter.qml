import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../Widgets"
import "../../Services"
import "./Components"

PanelWindow {
    id: root
    
    required property var modelData
    screen: modelData

    anchors {
        top: true
        right: true
    }
    
    margins {
        top: 10
        right: 10
    }
    
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    
    implicitWidth: contentItem.width
    implicitHeight: contentItem.height
    
    property bool isOpened: false
    
    visible: false
    
    Timer {
        id: hideTimer
        interval: 150
        onTriggered: {
            root.visible = false
        }
    }
    
    Connections {
        target: ControlCenterState
        function onToggleRequested() {
            root.toggle()
        }
    }
    
    // Auto-hide functionality
    // Close the menu when clicking on the transparent background outside the content
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (isOpened) root.toggle()
        }
    }

    Item {
        id: contentItem
        width: 380
        height: 480 // Reduced height slightly to be more compact like Gnome
        opacity: root.isOpened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // Block clicks from passing through the actual window content
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        // Main background panel
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.95) // Slight transparency 
            border.color: Theme.surface
            border.width: 1
            radius: 24 // More rounded
            clip: true
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20
                
                // Top Row (Battery, Settings, Power) - Gnome Style
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    // Battery (Simulated or mock if real service not bound here)
                    RowLayout {
                        spacing: 6
                        Text {
                            text: "󰁹"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            color: Theme.text
                        }
                        Text {
                            text: "100%"
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.text
                        }
                    }
                    
                    Item { Layout.fillWidth: true } // Spacer
                    
                    // Settings Icon
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: Theme.surface
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: Theme.text
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["gnome-control-center"]) // generic open settings command
                        }
                    }
                    
                    // Close Icon
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: Theme.surface
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: Theme.text
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggle() 
                        }
                    }

                    // Power / Logout Icon
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: Theme.surface
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: Theme.red
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggle() // Close logic or show logout menu
                        }
                    }
                }
                
                // Quick Settings Grid
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 12
                    
                    // Wi-Fi Toggle
                    QuickToggle {
                        Layout.fillWidth: true
                        isActive: Network.connected
                        activeIcon: "󰤨"
                        inactiveIcon: "󰤭"
                        activeText: "Wi-Fi"
                        inactiveText: "Wi-Fi"
                        subtext: Network.connected ? Network.activeConnection : "Disconnected"
                        onClicked: Quickshell.execDetached(["nm-connection-editor"])
                    }
                    
                    // Bluetooth Toggle
                    QuickToggle {
                        Layout.fillWidth: true
                        property bool btEnabled: true 
                        isActive: btEnabled
                        activeIcon: "󰂯"
                        inactiveIcon: "󰂲"
                        activeText: "Bluetooth"
                        inactiveText: "Bluetooth"
                        subtext: btEnabled ? "On" : "Off"
                        onClicked: {
                            btEnabled = !btEnabled
                            Quickshell.execDetached(["blueman-manager"])
                        }
                    }
                    
                    // Theme Mode Toggle
                    QuickToggle {
                        Layout.fillWidth: true
                        property bool darkMode: true
                        isActive: darkMode
                        activeIcon: "󰖨"
                        inactiveIcon: "󰖾"
                        activeText: "Dark Style"
                        inactiveText: "Light Style"
                        subtext: "System"
                        onClicked: darkMode = !darkMode
                    }

                    // Do Not Disturb
                    QuickToggle {
                        Layout.fillWidth: true
                        isActive: Notifications.dnd
                        activeIcon: "󰂛"
                        inactiveIcon: "󰂚"
                        activeText: "DND"
                        inactiveText: "DND"
                        subtext: isActive ? "Silenced" : "Active"
                        onClicked: Notifications.dnd = !Notifications.dnd
                    }
                }
                
                // Sliders Box
                Rectangle {
                    Layout.fillWidth: true
                    height: 140
                    radius: 24
                    color: "transparent"
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 16
                        
                        // Volume
                        VolumeSlider {
                            Layout.fillWidth: true
                        }
                        
                        // Brightness Mock Slider (Mimicking VolumeSlider Style)
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 50 // Same as VolumeSlider
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 16
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 48
                                    radius: 24
                                    color: Theme.surface
                                    
                                    property real brightnessVal: 0.8
                                    
                                    Rectangle {
                                        width: Math.max(height, parent.width * parent.brightnessVal)
                                        height: parent.height
                                        radius: parent.radius
                                        color: Theme.primary
                                    }
                                    
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰃠"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 20
                                        color: Theme.base
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Filler space
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
    
    // Expose a public method to toggle visibility
    function toggle() {
        if (isOpened) {
            isOpened = false
            hideTimer.restart()
        } else {
            root.visible = true
            isOpened = true
        }
    }
}
