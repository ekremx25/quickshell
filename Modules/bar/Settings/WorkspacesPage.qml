pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Widgets"
import "../../../Services/core/Log.js" as Log

Item {
    id: root
    property var settingsPopup: null
    
    // Keep this page in sync with every built-in and Material You theme.
    property color colorText: Theme.text
    property color colorSubtext: Theme.subtext
    property color colorSurface: Theme.surface
    property color colorPrimary: Theme.primary
    property color colorBackground: Theme.background

    readonly property var workspaceConfig: settingsPopup && settingsPopup.barConfig && settingsPopup.barConfig.workspaces
        ? settingsPopup.barConfig.workspaces
        : ({})

    // Temporary selection state (Not yet saved)
    property string selectedFormat: workspaceConfig.format || "roman"
    property string selectedStyle: workspaceConfig.style || "square"
    property bool isTransparent: workspaceConfig.transparent !== false
    property string displayMode: workspaceConfig.displayMode || "role"
    property int workspaceCount: workspaceConfig.workspaceCount || 5
    property bool showEmpty: workspaceConfig.showEmpty !== false
    property bool showSpecial: workspaceConfig.showSpecial === true
    property bool showApps: workspaceConfig.showApps !== false
    property bool groupApps: workspaceConfig.groupApps !== false
    property bool scrollEnabled: workspaceConfig.scrollEnabled !== false
    property bool wrapAround: workspaceConfig.wrapAround !== false
    property bool reverseScroll: workspaceConfig.reverseScroll === true
    property int iconSize: workspaceConfig.iconSize || 20
    property int maxIcons: workspaceConfig.maxIcons || 4

    function resetWorkspaceSettings() {
        selectedFormat = "roman";
        selectedStyle = "square";
        isTransparent = true;
        displayMode = "role";
        workspaceCount = 5;
        showEmpty = true;
        showSpecial = false;
        showApps = true;
        groupApps = true;
        scrollEnabled = true;
        wrapAround = true;
        reverseScroll = false;
        iconSize = 20;
        maxIcons = 4;
    }

    function applyWorkspaceSettings() {
        var cfg = JSON.parse(JSON.stringify(settingsPopup.barConfig || {}));
        if (!cfg.workspaces) cfg.workspaces = {};

        cfg.workspaces.format = root.selectedFormat;
        cfg.workspaces.style = root.selectedStyle;
        cfg.workspaces.transparent = root.isTransparent;
        cfg.workspaces.displayMode = root.displayMode;
        cfg.workspaces.workspaceCount = root.workspaceCount;
        cfg.workspaces.showEmpty = root.showEmpty;
        cfg.workspaces.showSpecial = root.showSpecial;
        cfg.workspaces.showApps = root.showApps;
        cfg.workspaces.groupApps = root.groupApps;
        cfg.workspaces.scrollEnabled = root.scrollEnabled;
        cfg.workspaces.wrapAround = root.wrapAround;
        cfg.workspaces.reverseScroll = root.reverseScroll;
        cfg.workspaces.iconSize = root.iconSize;
        cfg.workspaces.maxIcons = root.maxIcons;

        settingsPopup.barConfig = cfg;
        settingsPopup.saveConfig();
        Log.debug("WorkspacesPage", "Workspace config saved");
    }

    component SettingSwitch: Switch {
        id: settingSwitchRoot
        indicator: Rectangle {
            implicitWidth: 40
            implicitHeight: 20
            radius: 10
            color: settingSwitchRoot.checked ? root.colorPrimary : root.colorSurface
            border.color: Qt.rgba(255, 255, 255, 0.1)

            Rectangle {
                x: settingSwitchRoot.checked ? parent.width - width - 2 : 2
                width: 16
                height: 16
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: "#ffffff"
                Behavior on x { NumberAnimation { duration: 100 } }
            }
        }
    }

    component ToggleCard: Rectangle {
        id: toggleCardRoot
        property string title: ""
        property string description: ""
        property alias checked: toggle.checked
        signal toggled(bool checked)

        Layout.fillWidth: true
        height: description.length > 0 ? 58 : 50
        color: Qt.rgba(root.colorSurface.r, root.colorSurface.g, root.colorSurface.b, 0.3)
        radius: 10

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: toggleCardRoot.title; font.pixelSize: 14; color: root.colorText; font.family: Theme.fontFamily }
                Text {
                    visible: text.length > 0
                    text: toggleCardRoot.description
                    font.pixelSize: 11
                    color: root.colorSubtext
                    font.family: Theme.fontFamily
                }
            }

            SettingSwitch {
                id: toggle
                onToggled: toggleCardRoot.toggled(checked)
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
            text: "Workspace Style" 
            font.bold: true 
            font.pixelSize: 24 
            color: colorText
        }

        Text { 
            font.family: Theme.fontFamily
            text: "Choose how your workspaces appear on the bar." 
            font.pixelSize: 14 
            color: colorSubtext 
        }

        Item { height: 10 }

        // Cards (Options)
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Repeater {
                model: ListModel {
                    ListElement { name: "Chinese"; value: "chinese"; preview: "一  二  三" }
                        ListElement { name: "Roman"; value: "roman"; preview: "I  II  III" }
                        ListElement { name: "Numbers"; value: "arabic"; preview: "1  2  3" }
                }

                delegate: Rectangle {
                    id: card
                    required property string name
                    required property string value
                    required property string preview
                    Layout.fillWidth: true
                    height: 120
                    radius: 12
                    color: root.selectedFormat === card.value
                           ? Qt.rgba(colorPrimary.r, colorPrimary.g, colorPrimary.b, 0.15) 
                           : Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.5)
                    
                    border.width: 2
                    border.color: root.selectedFormat === card.value ? colorPrimary : "transparent"

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            text: card.preview
                            font.pixelSize: 20
                            font.bold: true
                            font.family: Theme.fontFamily
                            color: root.selectedFormat === card.value ? colorPrimary : colorText
                        }

                        Text {
                            font.family: Theme.fontFamily
                            text: card.name
                            font.pixelSize: 14
                            color: colorSubtext
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedFormat = card.value
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Multi-monitor Layout"
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: 18
                color: colorText
            }

            Text {
                text: "Choose how workspace numbers are assigned to each monitor."
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: colorSubtext
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Repeater {
                    model: ListModel {
                        ListElement { name: "Role ranges"; value: "role"; detail: "Recommended for multiple monitors" }
                        ListElement { name: "Occupied only"; value: "occupied"; detail: "Hide unused workspaces" }
                        ListElement { name: "Global"; value: "global"; detail: "Show the same set everywhere" }
                    }

                    delegate: Rectangle {
                        id: modeCard
                        required property string name
                        required property string value
                        required property string detail
                        Layout.fillWidth: true
                        height: 76
                        radius: 10
                        color: root.displayMode === modeCard.value
                            ? Qt.rgba(colorPrimary.r, colorPrimary.g, colorPrimary.b, 0.15)
                            : Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                        border.width: 2
                        border.color: root.displayMode === modeCard.value ? colorPrimary : "transparent"

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: modeCard.name
                                color: root.displayMode === modeCard.value ? colorPrimary : colorText
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: modeCard.detail
                                color: colorSubtext
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.displayMode = modeCard.value
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 70
                radius: 10
                visible: root.displayMode === "role" || root.displayMode === "global"
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: root.displayMode === "role" ? "Workspaces per monitor" : "Visible workspace count"
                            color: colorText
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.workspaceCount
                            color: colorPrimary
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: 1
                        to: 20
                        stepSize: 1
                        value: root.workspaceCount
                        onMoved: root.workspaceCount = Math.round(value)
                    }
                }
            }

            ToggleCard {
                visible: root.displayMode !== "occupied"
                title: "Show empty workspaces"
                description: "Keep the selected range stable even when a workspace has no windows"
                checked: root.showEmpty
                onToggled: checked => root.showEmpty = checked
            }

            ToggleCard {
                title: "Show special workspaces"
                description: "Include Hyprland special/scratch workspaces in the indicator"
                checked: root.showSpecial
                onToggled: checked => root.showSpecial = checked
            }
        }

        // Style Selection
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 16

            Text { 
                font.family: Theme.fontFamily
                text: "Appearance Style" 
                font.bold: true 
                font.pixelSize: 18 
                color: colorText
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Repeater {
                    model: ListModel {
                        // ListElement { name: "Fill"; value: "fill" } // Removed
                        ListElement { name: "Square"; value: "square" }
                        ListElement { name: "Circle"; value: "circle" }
                        ListElement { name: "Outline"; value: "outline" }
                        ListElement { name: "Underline"; value: "underline" }
                        ListElement { name: "Overline"; value: "overline" }
                        ListElement { name: "Pipe"; value: "pipe" }
                        ListElement { name: "Dot"; value: "dot" }
                    }

                    delegate: Rectangle {
                        id: styleCard
                        required property string name
                        required property string value
                        Layout.fillWidth: true
                        height: 80
                        radius: 12
                        color: root.selectedStyle === styleCard.value
                               ? Qt.rgba(colorPrimary.r, colorPrimary.g, colorPrimary.b, 0.15) 
                               : Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.5)
                        
                        border.width: 2
                        border.color: root.selectedStyle === styleCard.value ? colorPrimary : "transparent"

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            // Icon / Representative Shape
                            Item {
                                width: 24
                                height: 24
                                Layout.alignment: Qt.AlignHCenter

                                property color shapeColor: root.selectedStyle === styleCard.value ? colorPrimary : colorText

                                // SQUARE
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 18; height: 18
                                    radius: 4
                                    color: parent.shapeColor
                                    visible: styleCard.value === "square"
                                }

                                // CIRCLE
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 18; height: 18
                                    radius: 9
                                    color: parent.shapeColor
                                    visible: styleCard.value === "circle"
                                }

                                // OUTLINE
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 18; height: 18
                                    radius: 4
                                    color: "transparent"
                                    border.color: parent.shapeColor
                                    border.width: 2
                                    visible: styleCard.value === "outline"
                                }

                                // UNDERLINE
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    width: 18; height: 2
                                    color: parent.shapeColor
                                    visible: styleCard.value === "underline"
                                }

                                // OVERLINE
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    width: 18; height: 2
                                    color: parent.shapeColor
                                    visible: styleCard.value === "overline"
                                }

                                // PIPE
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    width: 2; height: 18
                                    color: parent.shapeColor
                                    visible: styleCard.value === "pipe"
                                }

                                // DOT
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    width: 4; height: 4
                                    radius: 2
                                    color: parent.shapeColor
                                    visible: styleCard.value === "dot"
                                }
                            }

                            Text {
                                font.family: Theme.fontFamily
                                text: styleCard.name
                                font.pixelSize: 13
                                color: colorSubtext
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedStyle = styleCard.value
                        }
                    }
                }
            }
        }


        
        // Transparency Option
        Rectangle {
            Layout.fillWidth: true
            height: 50
            color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
            radius: 10
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16
                
                Text {
                    font.family: Theme.fontFamily
                    text: "Transparent Background"
                    font.pixelSize: 14
                    color: colorText
                    Layout.fillWidth: true
                }
                
                SettingSwitch {
                    checked: root.isTransparent
                    onToggled: root.isTransparent = checked
                }
            }
        }

        // DMS Features Toggles (Advanced Features)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Text { 
                font.family: Theme.fontFamily
                text: "Advanced Features" 
                font.bold: true 
                font.pixelSize: 18 
                color: colorText
            }

            // Show Workspace Apps Switch
            Rectangle {
                Layout.fillWidth: true
                height: 50
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 16
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {  text: "Show Workspace Apps"; font.pixelSize: 14; color: colorText; font.family: Theme.fontFamily }
                        Text {  text: "Display application icons in workspace indicators"; font.pixelSize: 11; color: colorSubtext; font.family: Theme.fontFamily }
                    }
                    
                    SettingSwitch {
                        checked: root.showApps
                        onToggled: root.showApps = checked
                    }
                }
            }

            // Group Workspace Apps Switch
            Rectangle {
                Layout.fillWidth: true
                height: 50
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10
                visible: root.showApps
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 16
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {  text: "Group Workspace Apps"; font.pixelSize: 14; color: colorText; font.family: Theme.fontFamily }
                        Text {  text: "Group repeated application icons in workspaces"; font.pixelSize: 11; color: colorSubtext; font.family: Theme.fontFamily }
                    }
                    
                    SettingSwitch {
                        checked: root.groupApps
                        onToggled: root.groupApps = checked
                    }
                }
            }

            // Scroll to Switch Switch
            Rectangle {
                Layout.fillWidth: true
                height: 50
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 16
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {  text: "Scroll to Switch"; font.pixelSize: 14; color: colorText; font.family: Theme.fontFamily }
                        Text {  text: "Switch active workspaces by scrolling over the bar"; font.pixelSize: 11; color: colorSubtext; font.family: Theme.fontFamily }
                    }
                    
                    SettingSwitch {
                        checked: root.scrollEnabled
                        onToggled: root.scrollEnabled = checked
                    }
                }
            }

            ToggleCard {
                visible: root.scrollEnabled
                title: "Wrap around"
                description: "Continue from the last visible workspace to the first"
                checked: root.wrapAround
                onToggled: checked => root.wrapAround = checked
            }

            ToggleCard {
                visible: root.scrollEnabled
                title: "Reverse scroll direction"
                description: "Swap the next and previous workspace scroll directions"
                checked: root.reverseScroll
                onToggled: checked => root.reverseScroll = checked
            }

            // Icon Size Slider
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10
                visible: root.showApps
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4
                    
                    RowLayout {
                        Layout.fillWidth: true
                        Text {  text: "App Icon Size"; font.pixelSize: 14; color: colorText; Layout.fillWidth: true; font.family: Theme.fontFamily }
                        Text {  text: Math.round(root.iconSize) + "px"; font.pixelSize: 14; color: colorPrimary; font.bold: true; font.family: Theme.fontFamily }
                    }
                    
                    Slider {
                        id: iconSizeSlider
                        Layout.fillWidth: true
                        from: 10
                        to: 36
                        stepSize: 1
                        value: root.iconSize
                        onValueChanged: root.iconSize = value
                        
                        background: Rectangle {
                            x: iconSizeSlider.leftPadding
                            y: iconSizeSlider.topPadding + iconSizeSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 4
                            width: iconSizeSlider.availableWidth
                            height: implicitHeight
                            radius: 2
                            color: colorSurface
                            
                            Rectangle {
                                width: iconSizeSlider.visualPosition * parent.width
                                height: parent.height
                                color: colorPrimary
                                radius: 2
                            }
                        }
                        
                        handle: Rectangle {
                            x: iconSizeSlider.leftPadding + iconSizeSlider.visualPosition * (iconSizeSlider.availableWidth - width)
                            y: iconSizeSlider.topPadding + iconSizeSlider.availableHeight / 2 - height / 2
                            implicitWidth: 16
                            implicitHeight: 16
                            radius: 8
                            color: iconSizeSlider.pressed ? Qt.darker(colorPrimary, 1.2) : colorPrimary
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3)
                radius: 10
                visible: root.showApps

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Maximum icons per workspace"; font.pixelSize: 14; color: colorText; Layout.fillWidth: true; font.family: Theme.fontFamily }
                        Text { text: root.maxIcons; font.pixelSize: 14; color: colorPrimary; font.bold: true; font.family: Theme.fontFamily }
                    }

                    Slider {
                        Layout.fillWidth: true
                        from: 1
                        to: 12
                        stepSize: 1
                        value: root.maxIcons
                        onMoved: root.maxIcons = Math.round(value)
                    }
                }
            }
        }

        // Flexible Spacer
        Item { Layout.fillHeight: true; implicitHeight: 20 }

        // Bottom Bar (Apply Button)
        RowLayout {
            Layout.fillWidth: true

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40
                radius: 10
                color: resetArea.pressed ? Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.8)
                    : Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.5)
                border.width: 1
                border.color: colorSubtext

                Text {
                    anchors.centerIn: parent
                    text: "Reset defaults"
                    color: colorText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                MouseArea {
                    id: resetArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetWorkspaceSettings()
                }
            }

            Item { Layout.fillWidth: true } // Align Right

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40
                radius: 10
                color: applyArea.pressed ? Qt.darker(colorPrimary, 1.1) : colorPrimary
                
                Text {
                    font.family: Theme.fontFamily
                    anchors.centerIn: parent
                    text: "Apply"
                    color: colorBackground
                    font.bold: true
                    font.pixelSize: 14
                }

                MouseArea {
                    id: applyArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.applyWorkspaceSettings()
                }
            }
        }
    }
}
}
