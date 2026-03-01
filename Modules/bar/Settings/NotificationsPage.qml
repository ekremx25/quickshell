import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Services" as S

Item {
    id: root
    property var settingsPopup: null
    
    // Tema renkleri
    property color colorText: "#cdd6f4"
    property color colorSubtext: "#a6adc8"
    property color colorSurface: "#313244"
    property color colorPrimary: "#cba6f7"
    property color colorBackground: "#1e1e2e"

    property var notifService: S.Notifications

    Flickable {
        anchors.fill: parent
        contentHeight: contentCol.implicitHeight + 48
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contentCol
            width: parent.width - 48
            x: 24
            y: 24
            spacing: 20

            // Title
            Text { 
                text: "Notification Settings" 
                font.bold: true 
                font.pixelSize: 24 
                color: colorText
            }

            Text { 
                text: "Manage how notifications behave and appear." 
                font.pixelSize: 14 
                color: colorSubtext 
            }

            Item { height: 10 }

            // DND Switch
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 16
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Do Not Disturb (DND)"; font.pixelSize: 14; color: colorText }
                        Text { text: "Silence all incoming notification popups."; font.pixelSize: 11; color: colorSubtext }
                    }
                    
                    Switch {
                        checked: notifService.dnd
                        onToggled: notifService.dnd = checked
                        
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 20; radius: 10
                            color: parent.checked ? colorPrimary : colorSurface
                            border.color: Qt.rgba(255,255,255,0.1)
                            Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 100 } } }
                        }
                    }
                }
            }

            // Popup Position
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 16
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Popup Position"; font.pixelSize: 14; color: colorText }
                        Text { text: "Choose where notification popups appear on screen."; font.pixelSize: 11; color: colorSubtext }
                    }
                    
                    ComboBox {
                        id: positionCombo
                        implicitWidth: 150
                        model: ["Top Right", "Top Left", "Top Center", "Bottom Center", "Bottom Right", "Bottom Left"]
                        currentIndex: {
                            switch(notifService.popupPosition) {
                                case 1: return 0;
                                case 2: return 1;
                                case 3: return 2;
                                case 4: return 3;
                                case 5: return 4;
                                case 6: return 5;
                                default: return 0;
                            }
                        }
                        onActivated: {
                            switch(currentIndex) {
                                case 0: notifService.popupPosition = 1; break;
                                case 1: notifService.popupPosition = 2; break;
                                case 2: notifService.popupPosition = 3; break;
                                case 3: notifService.popupPosition = 4; break;
                                case 4: notifService.popupPosition = 5; break;
                                case 5: notifService.popupPosition = 6; break;
                            }
                        }
                    }
                }
            }

            // Overlay Switch
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 16
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Notification Overlay"; font.pixelSize: 14; color: colorText }
                        Text { text: "Display all priorities over fullscreen apps."; font.pixelSize: 11; color: colorSubtext }
                    }
                    
                    Switch {
                        checked: notifService.overlayEnabled
                        onToggled: notifService.overlayEnabled = checked
                        
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 20; radius: 10
                            color: parent.checked ? colorPrimary : colorSurface
                            border.color: Qt.rgba(255,255,255,0.1)
                            Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 100 } } }
                        }
                    }
                }
            }

            // Compact Switch
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 16
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Compact"; font.pixelSize: 14; color: colorText }
                        Text { text: "Use smaller notification cards."; font.pixelSize: 11; color: colorSubtext }
                    }
                    
                    Switch {
                        checked: notifService.compactMode
                        onToggled: notifService.compactMode = checked
                        
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 20; radius: 10
                            color: parent.checked ? colorPrimary : colorSurface
                            border.color: Qt.rgba(255,255,255,0.1)
                            Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 100 } } }
                        }
                    }
                }
            }

            // Popup Shadow Switch
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 16
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Popup Shadow"; font.pixelSize: 14; color: colorText }
                        Text { text: "Show drop shadow on notification popups."; font.pixelSize: 11; color: colorSubtext }
                    }
                    
                    Switch {
                        checked: notifService.popupShadowEnabled
                        onToggled: notifService.popupShadowEnabled = checked
                        
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 20; radius: 10
                            color: parent.checked ? colorPrimary : colorSurface
                            border.color: Qt.rgba(255,255,255,0.1)
                            Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 100 } } }
                        }
                    }
                }
            }

            // Privacy Mode Switch
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 16
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Privacy Mode"; font.pixelSize: 14; color: colorText }
                        Text { text: "Hide notification content until expanded."; font.pixelSize: 11; color: colorSubtext }
                    }
                    
                    Switch {
                        checked: notifService.privacyMode
                        onToggled: notifService.privacyMode = checked
                        
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 20; radius: 10
                            color: parent.checked ? colorPrimary : colorSurface
                            border.color: Qt.rgba(255,255,255,0.1)
                            Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 100 } } }
                        }
                    }
                }
            }

            // Animation Speed
            Rectangle {
                Layout.fillWidth: true
                height: 90
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Animation Speed"; font.pixelSize: 14; color: colorText }
                        Text { text: "Control animation duration for notification popups and history."; font.pixelSize: 11; color: colorSubtext }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        
                        Repeater {
                            model: ListModel {
                                ListElement { name: "None"; value: 0 }
                                ListElement { name: "Short"; value: 1 }
                                ListElement { name: "Medium"; value: 2 }
                                ListElement { name: "Long"; value: 3 }
                                ListElement { name: "Custom"; value: 4 }
                            }
                            delegate: Rectangle {
                                width: 80
                                height: 30
                                radius: 6
                                color: notifService.animationSpeed === model.value ? colorPrimary : Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.8)
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: notifService.animationSpeed === model.value ? "  " + model.name : model.name
                                    font.pixelSize: 12
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: notifService.animationSpeed === model.value ? colorBackground : colorText
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: notifService.animationSpeed = model.value
                                }
                            }
                        }
                    }
                }
            }

            // Duration Slider
            Rectangle {
                Layout.fillWidth: true
                height: 80
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4
                    
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: "Popup Duration"; font.pixelSize: 14; color: colorText }
                            Text { text: "How long a notification stays on the screen."; font.pixelSize: 11; color: colorSubtext }
                        }
                        Text { text: Math.round(notifService.displayDuration / 1000) + "s"; font.pixelSize: 14; color: colorPrimary; font.bold: true }
                    }
                    
                    Slider {
                        Layout.fillWidth: true
                        from: 1000
                        to: 60000
                        stepSize: 1000
                        value: notifService.displayDuration
                        onValueChanged: notifService.displayDuration = value
                        
                        background: Rectangle {
                            x: parent.leftPadding
                            y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 4
                            width: parent.availableWidth
                            height: implicitHeight
                            radius: 2
                            color: colorSurface
                            
                            Rectangle {
                                width: parent.parent.visualPosition * parent.width
                                height: parent.height
                                color: colorPrimary
                                radius: 2
                            }
                        }
                        
                        handle: Rectangle {
                            x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                            y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            implicitWidth: 16
                            implicitHeight: 16
                            radius: 8
                            color: parent.pressed ? Qt.darker(colorPrimary, 1.2) : colorPrimary
                        }
                    }
                }
            }

            // Clear All History Button
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 16
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Clear Notification History"; font.pixelSize: 14; color: colorText }
                        Text { text: "Remove all saved notifications from memory."; font.pixelSize: 11; color: colorSubtext }
                    }
                    
                    Rectangle {
                        width: 100
                        height: 36
                        radius: 8
                        color: clearHover.containsMouse ? Qt.darker("#f38ba8", 1.2) : "#f38ba8"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Clear All"
                            color: "#1e1e2e"
                            font.pixelSize: 13
                            font.bold: true
                        }
                        
                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                notifService.notifications = []
                                notifService.refreshActiveNotifications()
                            }
                        }
                    }
                }
            }
        }
    }
}
