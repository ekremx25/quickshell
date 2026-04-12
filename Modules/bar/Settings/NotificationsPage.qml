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
    readonly property var popupPositionOptions: [
        { label: "Top Right", value: 1 },
        { label: "Top Left", value: 2 },
        { label: "Top Center", value: 3 },
        { label: "Bottom Center", value: 4 },
        { label: "Bottom Right", value: 5 },
        { label: "Bottom Left", value: 6 }
    ]

    function popupPositionIndex(value) {
        for (var i = 0; i < popupPositionOptions.length; ++i) {
            if (popupPositionOptions[i].value === value) return i;
        }
        return 0;
    }

    function popupPositionValue(index) {
        return popupPositionOptions[index] ? popupPositionOptions[index].value : popupPositionOptions[0].value;
    }

    function popupPositionLabels() {
        var labels = [];
        for (var i = 0; i < popupPositionOptions.length; ++i) {
            labels.push(popupPositionOptions[i].label);
        }
        return labels;
    }

    component ToggleSettingCard : Rectangle {
        id: toggleCard
        property string title: ""
        property string description: ""
        property bool checked: false
        signal toggled(bool checked)

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
                Text { text: toggleCard.title; font.pixelSize: 14; color: colorText }
                Text { text: toggleCard.description; font.pixelSize: 11; color: colorSubtext }
            }

            Switch {
                checked: toggleCard.checked
                onToggled: toggleCard.toggled(checked)

                indicator: Rectangle {
                    implicitWidth: 40; implicitHeight: 20; radius: 10
                    color: parent.checked ? colorPrimary : colorSurface
                    border.color: Qt.rgba(255,255,255,0.1)
                    Rectangle {
                        x: parent.parent.checked ? parent.width - width - 2 : 2
                        width: 16; height: 16; radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#ffffff"
                        Behavior on x { NumberAnimation { duration: 100 } }
                    }
                }
            }
        }
    }

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

            ToggleSettingCard {
                title: "Do Not Disturb (DND)"
                description: "Silence all incoming notification popups."
                checked: notifService.dnd
                onToggled: checked => notifService.dnd = checked
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
                        model: popupPositionLabels()
                        currentIndex: popupPositionIndex(notifService.popupPosition)
                        onActivated: notifService.popupPosition = popupPositionValue(currentIndex)
                    }
                }
            }

            ToggleSettingCard {
                title: "Notification Overlay"
                description: "Display all priorities over fullscreen apps."
                checked: notifService.overlayEnabled
                onToggled: checked => notifService.overlayEnabled = checked
            }

            ToggleSettingCard {
                title: "Compact"
                description: "Use smaller notification cards."
                checked: notifService.compactMode
                onToggled: checked => notifService.compactMode = checked
            }

            ToggleSettingCard {
                title: "Popup Shadow"
                description: "Show drop shadow on notification popups."
                checked: notifService.popupShadowEnabled
                onToggled: checked => notifService.popupShadowEnabled = checked
            }

            ToggleSettingCard {
                title: "Privacy Mode"
                description: "Hide notification content until expanded."
                checked: notifService.privacyMode
                onToggled: checked => notifService.privacyMode = checked
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
