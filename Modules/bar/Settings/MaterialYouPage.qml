import QtQuick
import QtQuick.Layouts
import "SettingsPalette.js" as SettingsPalette
import "../../../Widgets"
import "../../../Services"
import Qt.labs.platform

Item {
    id: materialPage
    readonly property color accentColor: SettingsPalette.readableAccent(Theme.primary)
    readonly property color accentTextColor: SettingsPalette.foregroundFor(accentColor)
    readonly property color successColor: SettingsPalette.readableAccent(Theme.green)
    readonly property color errorColor: SettingsPalette.readableAccent(Theme.red)
    readonly property color warningColor: SettingsPalette.readableAccent(Theme.yellow)
    readonly property bool staticScheme: ColorPaletteService.isStaticType(ColorPaletteService.matugenType)
    readonly property color chipIdleBg: Qt.rgba(255, 255, 255, 0.04)
    readonly property color chipSelectedBg: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.16)
    readonly property color chipSelectedBorder: accentColor
    readonly property color chipSelectedText: SettingsPalette.text

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
                Text { text: ""; font.pixelSize: 20; font.family: Theme.fontFamily; color: materialPage.accentColor }
                Text {  text: "Material You"; font.bold: true; font.pixelSize: 18; color: SettingsPalette.text; font.family: Theme.fontFamily }
                Item { Layout.fillWidth: true }

                // Availability badge
                Rectangle {
                    width: availText.width + 14; height: 24; radius: 12
                    color: ColorPaletteService.available
                        ? SettingsPalette.withAlpha(materialPage.successColor, 0.15)
                        : SettingsPalette.withAlpha(materialPage.errorColor, 0.15)

                    Text {
                        font.family: Theme.fontFamily
                        id: availText; anchors.centerIn: parent
                        text: ColorPaletteService.available ? "matugen ✓" : "matugen ✗"
                        font.pixelSize: 10
                        color: ColorPaletteService.available ? materialPage.successColor : materialPage.errorColor
                    }
                }
            }

            // Not available warning
            Rectangle {
                visible: !ColorPaletteService.available
                Layout.fillWidth: true
                height: 50; radius: 10
                color: SettingsPalette.withAlpha(materialPage.warningColor, 0.1)

                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    Text {  text: "⚠"; font.pixelSize: 18; font.family: Theme.fontFamily }
                    ColumnLayout {
                        spacing: 2
                        Text {  text: "matugen is not installed"; font.pixelSize: 12; font.bold: true; color: materialPage.warningColor; font.family: Theme.fontFamily }
                        Text {  text: "Install with: cargo install matugen"; font.pixelSize: 10; color: SettingsPalette.overlay2; font.family: Theme.fontFamily }
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

                    Text { text: ""; font.pixelSize: 16; font.family: Theme.fontFamily; color: materialPage.accentColor }
                    ColumnLayout {
                        spacing: 1
                        Text {  text: "Enable Material You"; font.pixelSize: 13; color: SettingsPalette.text; font.family: Theme.fontFamily }
                        Text {  text: "Extract theme colors from wallpaper"; font.pixelSize: 10; color: SettingsPalette.overlay2; font.family: Theme.fontFamily }
                    }
                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 44; height: 24; radius: 12
                        color: ColorPaletteService.enabled ? materialPage.accentColor : SettingsPalette.track
                        opacity: ColorPaletteService.available ? 1.0 : 0.4
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            width: 18; height: 18; radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            x: ColorPaletteService.enabled ? parent.width - width - 3 : 3
                            color: ColorPaletteService.enabled ? materialPage.accentTextColor : SettingsPalette.text
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

            Rectangle { Layout.fillWidth: true; height: 1; color: SettingsPalette.surface }

            // Dark / Light mode
            Text {  text: "Color Mode"; font.pixelSize: 13; font.bold: true; color: SettingsPalette.text; font.family: Theme.fontFamily }

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
                        opacity: materialPage.staticScheme && modelData.key === "light" ? 0.45 : 1.0
                        color: ColorPaletteService.mode === modelData.key ? materialPage.chipSelectedBg : materialPage.chipIdleBg
                        border.color: ColorPaletteService.mode === modelData.key ? materialPage.chipSelectedBorder : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.centerIn: parent; spacing: 8
                            Text { text: modelData.icon; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: ColorPaletteService.mode === modelData.key ? materialPage.chipSelectedText : SettingsPalette.subtext }
                            Text {  text: modelData.label; font.pixelSize: 13; color: ColorPaletteService.mode === modelData.key ? SettingsPalette.text : SettingsPalette.subtext; font.family: Theme.fontFamily }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !materialPage.staticScheme || modelData.key === "dark"
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: ColorPaletteService.setMode(modelData.key)
                        }
                    }
                }
            }

            Text {
                visible: materialPage.staticScheme
                text: "This authored palette currently provides a dark variant."
                color: SettingsPalette.overlay2
                font.pixelSize: 10
                font.family: Theme.fontFamily
            }

            // Matugen scheme type
            Text {  text: "Color Scheme Type"; font.pixelSize: 13; font.bold: true; color: SettingsPalette.text; font.family: Theme.fontFamily }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: ColorPaletteService.availableTypes

                    Rectangle {
                        width: schemeText.width + 18; height: 30; radius: 8
                        color: ColorPaletteService.matugenType === modelData ? materialPage.chipSelectedBg : materialPage.chipIdleBg
                        border.color: ColorPaletteService.matugenType === modelData ? materialPage.chipSelectedBorder : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            font.family: Theme.fontFamily
                            id: schemeText; anchors.centerIn: parent
                            text: ColorPaletteService.schemeLabel(modelData)
                            font.pixelSize: 11
                            color: ColorPaletteService.matugenType === modelData ? materialPage.chipSelectedText : SettingsPalette.subtext
                        }

                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ColorPaletteService.setMatugenType(modelData) }
                    }
                }
            }

            Text {
                visible: ColorPaletteService.matugenType === "scheme-wallpaper-spectrum"
                text: "Wallpaper Spectrum distributes the wallpaper palette across every bar module and automatically preserves text contrast."
                color: SettingsPalette.overlay2
                font.pixelSize: 10
                font.family: Theme.fontFamily
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item { height: 4 }

            // Wallpaper path input
            Text {  text: "Wallpaper Path"; font.pixelSize: 13; font.bold: true; color: SettingsPalette.text; font.family: Theme.fontFamily }

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
                        color: SettingsPalette.text
                        font.pixelSize: 12
                        clip: true
                        selectByMouse: true
                    }

                    // Live Update Toggle
                    Rectangle {
                        width: 50; height: 26; radius: 13
                        color: ColorPaletteService.liveUpdate ? materialPage.accentColor : SettingsPalette.track
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            x: ColorPaletteService.liveUpdate ? parent.width - width - 3 : 3
                            color: ColorPaletteService.liveUpdate ? materialPage.accentTextColor : SettingsPalette.text
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }

                        Text {
                            font.family: Theme.fontFamily
                            anchors.centerIn: parent
                            text: "Live"
                            font.pixelSize: 9; font.bold: true
                            color: ColorPaletteService.liveUpdate ? materialPage.accentTextColor : SettingsPalette.text
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
                            Text { text: "󰁯"; font.family: "JetBrainsMono Nerd Font"; color: SettingsPalette.text; font.pixelSize: 12 }
                            Text {  text: "Auto"; font.pixelSize: 11; font.bold: true; color: SettingsPalette.text; font.family: Theme.fontFamily }
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
                        Text {  anchors.centerIn: parent; text: "📂"; font.pixelSize: 11; font.family: Theme.fontFamily }

                        MouseArea {
                            id: browseMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: fileDialog.open()
                        }
                    }

                    // Generate
                    Rectangle {
                        width: genBtn.width + 16; height: 26; radius: 6
                        color: genMA.containsMouse ? Qt.lighter(materialPage.accentColor, 1.12) : materialPage.accentColor
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {  id: genBtn; anchors.centerIn: parent; text: ColorPaletteService.isBusy ? "⏳" : "Generate"; font.pixelSize: 11; font.bold: true; color: materialPage.accentTextColor; font.family: Theme.iconFontFamily }

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
                color: SettingsPalette.withAlpha(materialPage.errorColor, 0.1)
                Text {  anchors.centerIn: parent; text: ColorPaletteService.errorMessage; font.pixelSize: 11; color: materialPage.errorColor; font.family: Theme.fontFamily }
            }

            // Color preview
            Rectangle {
                visible: ColorPaletteService.enabled
                Layout.fillWidth: true; height: 50; radius: 10
                color: Qt.rgba(255,255,255,0.03)

                RowLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 8
                    Text {  text: "Preview:"; font.pixelSize: 11; color: SettingsPalette.subtext; font.family: Theme.fontFamily }

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
