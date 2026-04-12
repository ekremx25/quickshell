import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Services/core/Log.js" as Log

Item {
    id: root
    property var settingsPopup: null
    
    // Tema renkleri
    property color colorText: "#cdd6f4"
    property color colorSubtext: "#a6adc8"
    property color colorSurface: "#313244"
    property color colorPrimary: "#cba6f7"
    property color colorBackground: "#1e1e2e"

    readonly property var workspaceConfig: settingsPopup && settingsPopup.barConfig && settingsPopup.barConfig.workspaces
        ? settingsPopup.barConfig.workspaces
        : ({})

    // Geçici seçim durumu (Henüz kaydedilmemiş)
    property string selectedFormat: workspaceConfig.format || "chinese"
    property string selectedStyle: workspaceConfig.style || "fill"
    property bool isTransparent: workspaceConfig.transparent === true
    
    // Yeni özelliklerin geçici seçim durumu (DMS özellikleri)
    property bool showApps: workspaceConfig.showApps !== false
    property bool groupApps: workspaceConfig.groupApps !== false
    property bool scrollEnabled: workspaceConfig.scrollEnabled !== false
    property int iconSize: workspaceConfig.iconSize || 20

    function applyWorkspaceSettings() {
        var cfg = JSON.parse(JSON.stringify(settingsPopup.barConfig || {}));
        if (!cfg.workspaces) cfg.workspaces = {};

        cfg.workspaces.format = root.selectedFormat;
        cfg.workspaces.style = root.selectedStyle;
        cfg.workspaces.transparent = root.isTransparent;
        cfg.workspaces.showApps = root.showApps;
        cfg.workspaces.groupApps = root.groupApps;
        cfg.workspaces.scrollEnabled = root.scrollEnabled;
        cfg.workspaces.iconSize = root.iconSize;

        settingsPopup.barConfig = cfg;
        settingsPopup.saveConfig();
        Log.debug("WorkspacesPage", "Workspace config saved");
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
            text: "Workspace Style" 
            font.bold: true 
            font.pixelSize: 24 
            color: colorText
        }

        Text { 
            text: "Choose how your workspaces appear on the bar." 
            font.pixelSize: 14 
            color: colorSubtext 
        }

        Item { height: 10 }

        // Kartlar (Seçenekler)
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
                    Layout.fillWidth: true
                    height: 120
                    radius: 12
                    color: root.selectedFormat === model.value 
                           ? Qt.rgba(colorPrimary.r, colorPrimary.g, colorPrimary.b, 0.15) 
                           : Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.5)
                    
                    border.width: 2
                    border.color: root.selectedFormat === model.value ? colorPrimary : "transparent"

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            text: model.preview
                            font.pixelSize: 20
                            font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                            color: root.selectedFormat === model.value ? colorPrimary : colorText
                        }

                        Text {
                            text: model.name
                            font.pixelSize: 14
                            color: colorSubtext
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedFormat = model.value
                    }
                }
            }
        }

        // Style Selection
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 16

            Text { 
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
                        Layout.fillWidth: true
                        height: 80
                        radius: 12
                        color: root.selectedStyle === model.value 
                               ? Qt.rgba(colorPrimary.r, colorPrimary.g, colorPrimary.b, 0.15) 
                               : Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.5)
                        
                        border.width: 2
                        border.color: root.selectedStyle === model.value ? colorPrimary : "transparent"

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

                                property color shapeColor: root.selectedStyle === model.value ? colorPrimary : colorText

                                // SQUARE
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 18; height: 18
                                    radius: 4
                                    color: parent.shapeColor
                                    visible: model.value === "square"
                                }

                                // CIRCLE
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 18; height: 18
                                    radius: 9
                                    color: parent.shapeColor
                                    visible: model.value === "circle"
                                }

                                // OUTLINE
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 18; height: 18
                                    radius: 4
                                    color: "transparent"
                                    border.color: parent.shapeColor
                                    border.width: 2
                                    visible: model.value === "outline"
                                }

                                // UNDERLINE
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    width: 18; height: 2
                                    color: parent.shapeColor
                                    visible: model.value === "underline"
                                }

                                // OVERLINE
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    width: 18; height: 2
                                    color: parent.shapeColor
                                    visible: model.value === "overline"
                                }

                                // PIPE
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    width: 2; height: 18
                                    color: parent.shapeColor
                                    visible: model.value === "pipe"
                                }

                                // DOT
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    width: 4; height: 4
                                    radius: 2
                                    color: parent.shapeColor
                                    visible: model.value === "dot"
                                }
                            }

                            Text {
                                text: model.name
                                font.pixelSize: 13
                                color: colorSubtext
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedStyle = model.value
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
                    text: "Transparent Background"
                    font.pixelSize: 14
                    color: colorText
                    Layout.fillWidth: true
                }
                
                Switch {
                    checked: root.isTransparent
                    onToggled: root.isTransparent = checked
                    
                    // Basit stil
                    indicator: Rectangle {
                        implicitWidth: 40
                        implicitHeight: 20
                        radius: 10
                        color: parent.checked ? colorPrimary : colorSurface
                        border.color: Qt.rgba(255,255,255,0.1)
                        
                        Rectangle {
                            x: parent.parent.checked ? parent.width - width - 2 : 2
                            width: 16
                            height: 16
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#ffffff"
                            Behavior on x { NumberAnimation { duration: 100 } }
                        }
                    }
                }
            }
        }

        // DMS Features Toggles (Advanced Features)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Text { 
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
                        Text { text: "Show Workspace Apps"; font.pixelSize: 14; color: colorText }
                        Text { text: "Display application icons in workspace indicators"; font.pixelSize: 11; color: colorSubtext }
                    }
                    
                    Switch {
                        checked: root.showApps
                        onToggled: root.showApps = checked
                        
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 20; radius: 10
                            color: parent.checked ? colorPrimary : colorSurface
                            border.color: Qt.rgba(255,255,255,0.1)
                            Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 100 } } }
                        }
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
                        Text { text: "Group Workspace Apps"; font.pixelSize: 14; color: colorText }
                        Text { text: "Group repeated application icons in workspaces"; font.pixelSize: 11; color: colorSubtext }
                    }
                    
                    Switch {
                        checked: root.groupApps
                        onToggled: root.groupApps = checked
                        
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 20; radius: 10
                            color: parent.checked ? colorPrimary : colorSurface
                            border.color: Qt.rgba(255,255,255,0.1)
                            Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 100 } } }
                        }
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
                        Text { text: "Scroll to Switch"; font.pixelSize: 14; color: colorText }
                        Text { text: "Switch active workspaces by scrolling over the bar"; font.pixelSize: 11; color: colorSubtext }
                    }
                    
                    Switch {
                        checked: root.scrollEnabled
                        onToggled: root.scrollEnabled = checked
                        
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 20; radius: 10
                            color: parent.checked ? colorPrimary : colorSurface
                            border.color: Qt.rgba(255,255,255,0.1)
                            Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 100 } } }
                        }
                    }
                }
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
                        Text { text: "App Icon Size"; font.pixelSize: 14; color: colorText; Layout.fillWidth: true }
                        Text { text: Math.round(root.iconSize) + "px"; font.pixelSize: 14; color: colorPrimary; font.bold: true }
                    }
                    
                    Slider {
                        Layout.fillWidth: true
                        from: 10
                        to: 36
                        stepSize: 1
                        value: root.iconSize
                        onValueChanged: root.iconSize = value
                        
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
        }

        // Esnek Boşluk
        Item { Layout.fillHeight: true; implicitHeight: 20 }

        // Bottom Bar (Apply Button)
        RowLayout {
            Layout.fillWidth: true
            
            Item { Layout.fillWidth: true } // Align Right

            Rectangle {
                width: 120
                height: 40
                radius: 10
                color: applyArea.pressed ? Qt.darker(colorPrimary, 1.1) : colorPrimary
                
                Text {
                    anchors.centerIn: parent
                    text: "Apply"
                    color: "#1e1e2e" // Koyu yazı (Crust/Mantle)
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
