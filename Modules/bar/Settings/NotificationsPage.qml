import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Widgets"
import "../../../Services" as S
import "SettingsPalette.js" as SettingsPalette

Item {
    id: root
    property var settingsPopup: null
    
    // Keep Settings readable independently from the desktop's light/dark
    // palette. Only the accent follows the selected theme.
    property color colorText: SettingsPalette.text
    property color colorSubtext: SettingsPalette.subtext
    property color colorSurface: SettingsPalette.cardStrong
    property color colorPrimary: SettingsPalette.readableAccent(Theme.primary)
    property color colorPrimaryText: SettingsPalette.foregroundFor(colorPrimary)
    property color colorBackground: SettingsPalette.background
    property color colorDanger: SettingsPalette.readableAccent(Theme.red)

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

    function addFilteredAppFromInput() {
        if (notifService.addFilteredApp(filteredAppInput.text)) {
            filteredAppInput.text = "";
        }
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
                Text {  text: toggleCard.title; font.pixelSize: 14; color: colorText; font.family: Theme.fontFamily }
                Text {  text: toggleCard.description; font.pixelSize: 11; color: colorSubtext; font.family: Theme.fontFamily }
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
                        color: parent.parent.checked
                            ? root.colorPrimaryText
                            : SettingsPalette.text
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
                font.family: Theme.fontFamily
                text: "Notification Settings" 
                font.bold: true 
                font.pixelSize: 24 
                color: colorText
            }

            Text { 
                font.family: Theme.fontFamily
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
                        Text {  text: "Popup Position"; font.pixelSize: 14; color: colorText; font.family: Theme.fontFamily }
                        Text {  text: "Choose where notification popups appear on screen."; font.pixelSize: 11; color: colorSubtext; font.family: Theme.fontFamily }
                    }
                    
                    ComboBox {
                        id: positionCombo
                        implicitWidth: 150
                        implicitHeight: 36
                        model: popupPositionLabels()
                        currentIndex: popupPositionIndex(notifService.popupPosition)
                        onActivated: notifService.popupPosition = popupPositionValue(currentIndex)

                        contentItem: TextInput {
                            leftPadding: 12
                            rightPadding: 32
                            text: positionCombo.displayText
                            readOnly: true
                            selectByMouse: false
                            activeFocusOnTab: false
                            clip: true
                            color: root.colorText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                        }

                        indicator: Text {
                            x: positionCombo.width - width - 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⌄"
                            color: root.colorSubtext
                            font.pixelSize: 16
                            font.bold: true
                        }

                        background: Rectangle {
                            radius: 8
                            color: SettingsPalette.cardStrong
                            border.width: 1
                            border.color: positionCombo.activeFocus
                                ? root.colorPrimary
                                : SettingsPalette.border
                        }

                        delegate: ItemDelegate {
                            required property var modelData
                            required property int index
                            width: positionCombo.width
                            height: 34
                            highlighted: positionCombo.highlightedIndex === index
                            background: Rectangle {
                                color: parent.highlighted
                                    ? SettingsPalette.track
                                    : SettingsPalette.cardStrong
                            }
                            contentItem: Text {
                                text: parent.modelData
                                color: root.colorText
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        popup: Popup {
                            y: positionCombo.height + 4
                            width: positionCombo.width
                            implicitHeight: contentItem.implicitHeight + 2
                            padding: 1
                            contentItem: ListView {
                                clip: true
                                implicitHeight: contentHeight
                                model: positionCombo.popup.visible ? positionCombo.delegateModel : null
                                currentIndex: positionCombo.highlightedIndex
                            }
                            background: Rectangle {
                                radius: 8
                                color: SettingsPalette.cardStrong
                                border.color: SettingsPalette.border
                            }
                        }
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

            // Per-application notification filter
            Rectangle {
                Layout.fillWidth: true
                height: filterContent.implicitHeight + 24
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10

                ColumnLayout {
                    id: filterContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "Muted Applications"
                        font.pixelSize: 14
                        color: colorText
                        font.family: Theme.fontFamily
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Notifications from these exact application names are ignored."
                        font.pixelSize: 11
                        color: colorSubtext
                        font.family: Theme.fontFamily
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 38
                            radius: 8
                            color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.8)
                            border.color: filteredAppInput.activeFocus ? colorPrimary : Qt.rgba(255, 255, 255, 0.08)
                            border.width: 1

                            TextInput {
                                id: filteredAppInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: colorText
                                font.pixelSize: 12
                                font.family: Theme.fontFamily
                                selectByMouse: true
                                clip: true
                                onAccepted: root.addFilteredAppFromInput()

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Application name (for example Spotify)"
                                    color: colorSubtext
                                    font.pixelSize: 12
                                    font.family: Theme.fontFamily
                                    visible: filteredAppInput.text.length === 0 && !filteredAppInput.activeFocus
                                }
                            }
                        }

                        Rectangle {
                            width: 74
                            height: 38
                            radius: 8
                            color: addFilteredAppArea.containsMouse ? Qt.lighter(colorPrimary, 1.15) : colorPrimary
                            opacity: filteredAppInput.text.trim().length > 0 ? 1.0 : 0.45

                            Text {
                                anchors.centerIn: parent
                                text: "Add"
                                color: colorBackground
                                font.pixelSize: 12
                                font.bold: true
                                font.family: Theme.fontFamily
                            }

                            MouseArea {
                                id: addFilteredAppArea
                                anchors.fill: parent
                                enabled: filteredAppInput.text.trim().length > 0
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.addFilteredAppFromInput()
                            }
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: notifService.filteredApps.length > 0

                        Repeater {
                            model: notifService.filteredApps

                            Rectangle {
                                required property var modelData
                                radius: 8
                                width: filteredAppLabel.implicitWidth + 42
                                height: 30
                                color: Qt.rgba(colorPrimary.r, colorPrimary.g, colorPrimary.b, 0.12)
                                border.color: Qt.rgba(colorPrimary.r, colorPrimary.g, colorPrimary.b, 0.35)
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        id: filteredAppLabel
                                        text: modelData
                                        color: colorText
                                        font.pixelSize: 11
                                        font.family: Theme.fontFamily
                                    }

                                    Text {
                                        text: "×"
                                        color: removeFilteredAppArea.containsMouse ? root.colorDanger : colorSubtext
                                        font.pixelSize: 15
                                        font.bold: true
                                        font.family: Theme.fontFamily

                                        MouseArea {
                                            id: removeFilteredAppArea
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: notifService.removeFilteredApp(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: notifService.filteredApps.length === 0
                        text: "No applications are muted."
                        color: colorSubtext
                        font.pixelSize: 11
                        font.italic: true
                        font.family: Theme.fontFamily
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
                        Text {  text: "Animation Speed"; font.pixelSize: 14; color: colorText; font.family: Theme.fontFamily }
                        Text {  text: "Control animation duration for notification popups and history."; font.pixelSize: 11; color: colorSubtext; font.family: Theme.fontFamily }
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
                            Text {  text: "Popup Duration"; font.pixelSize: 14; color: colorText; font.family: Theme.fontFamily }
                            Text {  text: "How long a notification stays on the screen."; font.pixelSize: 11; color: colorSubtext; font.family: Theme.fontFamily }
                        }
                        Text {  text: Math.round(notifService.displayDuration / 1000) + "s"; font.pixelSize: 14; color: colorPrimary; font.bold: true; font.family: Theme.fontFamily }
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
                        Text {  text: "Clear Notification History"; font.pixelSize: 14; color: colorText; font.family: Theme.fontFamily }
                        Text {  text: "Remove all saved notifications from memory."; font.pixelSize: 11; color: colorSubtext; font.family: Theme.fontFamily }
                    }
                    
                    Rectangle {
                        width: 100
                        height: 36
                        radius: 8
                        color: clearHover.containsMouse ? Qt.darker(root.colorDanger, 1.2) : root.colorDanger
                        
                        Text {
                            font.family: Theme.fontFamily
                            anchors.centerIn: parent
                            text: "Clear All"
                            color: root.colorBackground
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
