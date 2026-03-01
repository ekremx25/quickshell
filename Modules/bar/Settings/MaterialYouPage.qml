import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"
import "../../../Services"
import Qt.labs.platform

Item {
    id: materialPage

    Flickable {
        anchors.fill: parent
        contentHeight: layout.implicitHeight
        clip: true

        ColumnLayout {
            id: layout
            width: parent.width
            anchors.margins: 16
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { text: ""; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
                Text { text: "Material You"; font.bold: true; font.pixelSize: 18; color: Theme.text }
                Item { Layout.fillWidth: true }

                // Availability badge
                Rectangle {
                    width: availText.width + 14; height: 24; radius: 12
                    color: ColorPaletteService.available ? Qt.rgba(166/255, 227/255, 161/255, 0.15) : Qt.rgba(243/255, 139/255, 168/255, 0.15)

                    Text {
                        id: availText; anchors.centerIn: parent
                        text: ColorPaletteService.available ? "matugen ✓" : "matugen ✗"
                        font.pixelSize: 10
                        color: ColorPaletteService.available ? Theme.green : Theme.red
                    }
                }
            }

            // Not available warning
            Rectangle {
                visible: !ColorPaletteService.available
                Layout.fillWidth: true
                height: 50; radius: 10
                color: Qt.rgba(249/255, 226/255, 175/255, 0.1)

                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    Text { text: "⚠"; font.pixelSize: 18 }
                    ColumnLayout {
                        spacing: 2
                        Text { text: "matugen is not installed"; font.pixelSize: 12; font.bold: true; color: Theme.yellow }
                        Text { text: "Install with: cargo install matugen"; font.pixelSize: 10; color: Theme.overlay2 }
                    }
                }
            }

            // Enable/Disable toggle
            Rectangle {
                Layout.fillWidth: true
                height: 50; radius: 10
                color: Qt.rgba(255,255,255,0.03)

                RowLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 10

                    Text { text: ""; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
                    ColumnLayout {
                        spacing: 1
                        Text { text: "Enable Material You"; font.pixelSize: 13; color: Theme.text }
                        Text { text: "Extract theme colors from wallpaper"; font.pixelSize: 10; color: Theme.overlay2 }
                    }
                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 44; height: 24; radius: 12
                        color: ColorPaletteService.enabled ? Theme.primary : Qt.rgba(255,255,255,0.1)
                        opacity: ColorPaletteService.available ? 1.0 : 0.4
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            width: 18; height: 18; radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            x: ColorPaletteService.enabled ? parent.width - width - 3 : 3
                            color: "white"
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: ColorPaletteService.available ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: { if (ColorPaletteService.available) ColorPaletteService.setEnabled(!ColorPaletteService.enabled); }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

            // Dark / Light mode
            Text { text: "Color Mode"; font.pixelSize: 13; font.bold: true; color: Theme.text }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { key: "dark", label: "Dark", icon: "󰖔" },
                        { key: "light", label: "Light", icon: "󰖕" }
                    ]

                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 10
                        color: ColorPaletteService.mode === modelData.key ? Qt.rgba(137/255, 180/255, 250/255, 0.15) : Qt.rgba(255,255,255,0.04)
                        border.color: ColorPaletteService.mode === modelData.key ? Theme.primary : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.centerIn: parent; spacing: 8
                            Text { text: modelData.icon; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: ColorPaletteService.mode === modelData.key ? Theme.primary : Theme.subtext }
                            Text { text: modelData.label; font.pixelSize: 13; color: ColorPaletteService.mode === modelData.key ? Theme.text : Theme.subtext }
                        }

                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ColorPaletteService.setMode(modelData.key) }
                    }
                }
            }

            // Matugen scheme type
            Text { text: "Color Scheme Type"; font.pixelSize: 13; font.bold: true; color: Theme.text }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: ColorPaletteService.availableTypes

                    Rectangle {
                        width: schemeText.width + 18; height: 30; radius: 8
                        color: ColorPaletteService.matugenType === modelData ? Qt.rgba(137/255, 180/255, 250/255, 0.15) : Qt.rgba(255,255,255,0.04)
                        border.color: ColorPaletteService.matugenType === modelData ? Theme.primary : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: schemeText; anchors.centerIn: parent
                            text: modelData.replace("scheme-", "")
                            font.pixelSize: 11
                            color: ColorPaletteService.matugenType === modelData ? Theme.primary : Theme.subtext
                        }

                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ColorPaletteService.setMatugenType(modelData) }
                    }
                }
            }

            Item { height: 4 }

            // Wallpaper path input
            Text { text: "Wallpaper Path"; font.pixelSize: 13; font.bold: true; color: Theme.text }

            Rectangle {
                Layout.fillWidth: true
                height: 40; radius: 8
                color: Qt.rgba(255,255,255,0.04)
                border.color: Qt.rgba(255,255,255,0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 8

                    TextInput {
                        id: wpInput
                        Layout.fillWidth: true
                        text: ColorPaletteService.wallpaperPath
                        color: Theme.text
                        font.pixelSize: 12
                        clip: true
                        selectByMouse: true
                    }

                    // Live Update Toggle
                    Rectangle {
                        width: 50; height: 26; radius: 13
                        color: ColorPaletteService.liveUpdate ? Theme.primary : Qt.rgba(255,255,255,0.1)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            x: ColorPaletteService.liveUpdate ? parent.width - width - 3 : 3
                            color: "white"
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Live"
                            font.pixelSize: 9; font.bold: true
                            color: ColorPaletteService.liveUpdate ? "#1e1e2e" : Theme.text
                            visible: !ColorPaletteService.liveUpdate // Show text when off
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ColorPaletteService.setLiveUpdate(!ColorPaletteService.liveUpdate)
                        }
                    }

                    // Auto Detect
                    Rectangle {
                        width: 90; height: 26; radius: 6
                        color: autoDetectMA.containsMouse ? Qt.rgba(255,255,255,0.1) : Qt.rgba(255,255,255,0.05)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "󰁯"; font.family: "JetBrainsMono Nerd Font"; color: Theme.text; font.pixelSize: 12 }
                            Text { text: "Auto"; font.pixelSize: 11; font.bold: true; color: Theme.text }
                        }

                        MouseArea {
                            id: autoDetectMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: ColorPaletteService.detectCurrentWallpaper()
                        }
                    }

                    // Browse
                    Rectangle {
                        width: 26; height: 26; radius: 6
                        color: browseMA.containsMouse ? Qt.rgba(255,255,255,0.1) : Qt.rgba(255,255,255,0.05)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { anchors.centerIn: parent; text: "📂"; font.pixelSize: 11 } // Folder icon

                        MouseArea {
                            id: browseMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: fileDialog.open()
                        }
                    }

                    // Generate
                    Rectangle {
                        width: genBtn.width + 16; height: 26; radius: 6
                        color: genMA.containsMouse ? Qt.lighter(Theme.primary, 1.2) : Theme.primary
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text { id: genBtn; anchors.centerIn: parent; text: ColorPaletteService.isBusy ? "⏳" : "Generate"; font.pixelSize: 11; font.bold: true; color: "#1e1e2e" }

                        MouseArea {
                            id: genMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (!ColorPaletteService.isBusy && wpInput.text.length > 0) ColorPaletteService.generateFromWallpaper(wpInput.text); }
                        }
                    }
                }
            }
            
            FileDialog {
                id: fileDialog
                title: "Select Wallpaper"
                nameFilters: ["Image files (*.jpg *.png *.jpeg *.webp)", "All files (*)"]
                folder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
                onAccepted: {
                    var path = fileDialog.file.toString().replace("file://", "");
                    ColorPaletteService.generateFromWallpaper(path);
                }
            }

            // Error message
            Rectangle {
                visible: ColorPaletteService.errorMessage.length > 0
                Layout.fillWidth: true; height: 32; radius: 6
                color: Qt.rgba(243/255, 139/255, 168/255, 0.1)
                Text { anchors.centerIn: parent; text: ColorPaletteService.errorMessage; font.pixelSize: 11; color: Theme.red }
            }

            // Color preview
            Rectangle {
                visible: ColorPaletteService.enabled
                Layout.fillWidth: true; height: 50; radius: 10
                color: Qt.rgba(255,255,255,0.03)

                RowLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 8
                    Text { text: "Preview:"; font.pixelSize: 11; color: Theme.subtext }

                    Repeater {
                        model: [
                            ColorPaletteService.primaryColor,
                            ColorPaletteService.secondaryColor,
                            ColorPaletteService.tertiaryColor,
                            ColorPaletteService.surfaceColor,
                            ColorPaletteService.backgroundColor,
                            ColorPaletteService.errorColor
                        ]
                        Rectangle {
                            width: 28; height: 28; radius: 6
                            color: modelData
                            border.color: Qt.rgba(255,255,255,0.1); border.width: 1
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
