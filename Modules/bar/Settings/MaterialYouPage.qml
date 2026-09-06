import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import Qt.labs.platform as Platform
import "../../../Widgets"
import "../../../Services"

Item {
    id: page
    readonly property color accent: SettingsPalette.readableAccent(Theme.primary)
    readonly property bool fixedPalette: ColorPaletteService.isStaticType(ColorPaletteService.matugenType)
    readonly property int customCount: Object.keys(ColorPaletteService.moduleAccentColors).length
    readonly property string appliedPath: ColorPaletteService.appliedWallpaperPath
    readonly property var descriptions: ({
        "scheme-wallpaper-spectrum": "Distinct accents sampled from your wallpaper.",
        "scheme-tonal-spot": "Soft, balanced colors for everyday use.",
        "scheme-neutral": "Quiet surfaces with restrained accents.",
        "scheme-fidelity": "Stay close to the source image's colors.",
        "scheme-vibrant": "Stronger color and expressive accents.",
        "scheme-expressive": "Unexpected hues with a balanced finish.",
        "scheme-fruit-salad": "Playful combinations of contrasting hues.",
        "scheme-rainbow": "A lively spread of complementary colors.",
        "scheme-monochrome": "A clean black-and-white desktop.",
        "scheme-content": "A palette built around the source color.",
        "scheme-catppuccin": "Warm pastels on a soft dark canvas.",
        "scheme-kanagawa": "Muted ink tones inspired by painting.",
        "scheme-tokyo-night": "Cool night tones with bright accents."
    })
    function imageUrl(path) {
        return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "";
    }

    component Label: Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pixelSize: 12
        color: SettingsPalette.subtext
    }
    component Heading: Label {
        color: SettingsPalette.text
        font.pixelSize: 18
        font.bold: true
    }
    component Card: Rectangle {
        default property alias content: body.data
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + 36
        radius: 16
        color: SettingsPalette.surface
        border.color: SettingsPalette.withAlpha(SettingsPalette.text, 0.09)
        ColumnLayout {
            id: body
            x: 18; y: 18
            width: parent.width - 36
            spacing: 14
        }
    }
    component Toggle: Controls.Switch {
        id: toggle
        focusPolicy: Qt.StrongFocus
        implicitWidth: 48; implicitHeight: 32
        padding: 0
        indicator: Rectangle {
            x: 0; y: 3
            width: 48; height: 26; radius: 13
            color: toggle.checked ? page.accent : SettingsPalette.track
            border.width: toggle.activeFocus ? 2 : 1
            border.color: toggle.activeFocus ? SettingsPalette.text : SettingsPalette.border
            Behavior on color { ColorAnimation { duration: 140 } }
            Rectangle {
                x: toggle.checked ? 25 : 3
                y: 3; width: 20; height: 20; radius: 10
                color: toggle.checked ? SettingsPalette.foregroundFor(page.accent) : SettingsPalette.text
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }
        opacity: enabled ? 1 : 0.45
    }

    Flickable {
        id: scroll
        objectName: "materialYouScroll"
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: body.implicitHeight + 40
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        Controls.ScrollBar.vertical: Controls.ScrollBar { }
        ColumnLayout {
            id: body
            width: Math.max(0, Math.min(1100, scroll.width - 32))
            x: (scroll.width - width) / 2
            y: 16
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Heading { text: "Material You"; font.pixelSize: 28 }
                    Label { text: "A desktop that feels like yours. Shape the palette, then make it personal." }
                }
                Toggle {
                    checked: ColorPaletteService.enabled
                    enabled: ColorPaletteService.available
                    Accessible.name: "Enable Material You"
                    onToggled: ColorPaletteService.setEnabled(checked)
                }
            }

            Card {
                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        Heading { text: ColorPaletteService.enabled ? ColorPaletteService.schemeLabel(ColorPaletteService.matugenType) : "Your current theme" }
                        Label {
                            text: !ColorPaletteService.enabled ? "Material You is off. Enable it to apply a wallpaper palette."
                                : page.fixedPalette ? "Fixed palette · Dark appearance"
                                : (ColorPaletteService.mode === "light" ? "Light appearance" : "Dark appearance")
                                    + (ColorPaletteService.liveUpdate ? " · Following desktop wallpaper" : " · Selected image")
                        }
                    }
                    Controls.BusyIndicator {
                        implicitWidth: 28; implicitHeight: 28
                        running: ColorPaletteService.isBusy
                        visible: running
                        Accessible.name: "Generating palette"
                    }
                }
                // Real module colors, including saved custom overrides.
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: [
                            {label:"Launcher", tint:Theme.launcherColor},
                            {label:"Workspaces", tint:Theme.workspacesColor},
                            {label:"Memory", tint:Theme.ramColor},
                            {label:"Media", tint:Theme.mediaColor}
                        ]
                        Rectangle {
                            required property var modelData
                            width: previewText.implicitWidth + 28
                            height: 36; radius: 18
                            color: modelData.tint
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Text {
                                id: previewText
                                anchors.centerIn: parent
                                text: modelData.label
                                color: Theme.foregroundFor(parent.color)
                                font.family: Theme.fontFamily
                                font.pixelSize: 12; font.bold: true
                            }
                        }
                    }
                }
                Label {
                    text: page.customCount === 0 ? "All module colors follow the palette."
                        : page.customCount + " custom colors stay fixed when the wallpaper changes. Edit them below."
                }
            }

            Card {
                visible: !ColorPaletteService.available || ColorPaletteService.errorMessage.length > 0
                Label {
                    color: SettingsPalette.readableAccent(Theme.red)
                    text: !ColorPaletteService.available
                        ? "Wallpaper colors need matugen. Install it to enable Material You."
                        : ColorPaletteService.errorMessage
                }
            }

            Card {
                Heading { text: "01  Color source" }
                Label { text: page.fixedPalette ? "This fixed theme does not use wallpaper colors. Your source is kept for wallpaper-based themes." : "Choose an image or follow your desktop automatically." }
                GridLayout {
                    Layout.fillWidth: true
                    columns: width >= 650 ? 2 : 1
                    columnSpacing: 18; rowSpacing: 14
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 260
                        Layout.preferredHeight: 154
                        color: SettingsPalette.cardStrong
                        radius: 10
                        clip: true
                        Image {
                            id: wallpaperImage
                            anchors.fill: parent
                            source: page.imageUrl(page.appliedPath || ColorPaletteService.wallpaperPath)
                            sourceSize.width: 600; sourceSize.height: 300
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: wallpaperImage.status !== Image.Ready
                            text: wallpaperImage.status === Image.Loading ? "Loading image…" : "No image preview"
                            color: SettingsPalette.subtext
                            font.family: Theme.fontFamily; font.pixelSize: 12
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 400
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 3
                                Label { text: "Follow desktop wallpaper"; color: SettingsPalette.text; font.bold: true }
                                Label { text: page.fixedPalette ? "Available with wallpaper-based themes." : "Update colors when your background changes."; font.pixelSize: 11 }
                            }
                            Toggle {
                                enabled: !page.fixedPalette && ColorPaletteService.available
                                checked: ColorPaletteService.liveUpdate
                                Accessible.name: "Follow desktop wallpaper"
                                onToggled: ColorPaletteService.setLiveUpdate(checked)
                            }
                        }
                        Controls.TextField {
                            id: pathInput
                            Layout.fillWidth: true
                            implicitHeight: 38
                            text: ColorPaletteService.wallpaperPath
                            placeholderText: "Image path"
                            color: SettingsPalette.text
                            placeholderTextColor: SettingsPalette.subtext
                            font.family: Theme.fontFamily; font.pixelSize: 12
                            selectByMouse: true
                            Accessible.name: "Wallpaper image path"
                            background: Rectangle {
                                color: SettingsPalette.background; radius: 8
                                border.color: pathInput.activeFocus ? page.accent : SettingsPalette.border
                            }
                            onAccepted: {
                                if (!page.fixedPalette && ColorPaletteService.available && text.trim())
                                    ColorPaletteService.selectWallpaper(text.trim());
                            }
                        }
                        Flow {
                            Layout.fillWidth: true; spacing: 8
                            ColorEditorButton { text: "Browse image"; enabled: !page.fixedPalette && ColorPaletteService.available; onClicked: fileDialog.open() }
                            ColorEditorButton { text: "Use desktop"; enabled: !page.fixedPalette && ColorPaletteService.available; onClicked: ColorPaletteService.useDesktopWallpaper() }
                            ColorEditorButton {
                                text: ColorPaletteService.isBusy ? "Generating…" : "Generate palette"
                                prominent: true
                                enabled: !page.fixedPalette && ColorPaletteService.available && pathInput.text.trim().length > 0 && !ColorPaletteService.isBusy
                                onClicked: ColorPaletteService.selectWallpaper(pathInput.text.trim())
                            }
                        }
                    }
                }
                Label {
                    text: ColorPaletteService.isBusy ? "Generating colors…"
                        : page.fixedPalette ? "Wallpaper preview is informational for this fixed theme."
                        : page.appliedPath ? "Applied: " + page.appliedPath : "Choose a source to generate your first palette."
                    font.pixelSize: 11
                }
                Label {
                    visible: ColorPaletteService.liveUpdate && !page.fixedPalette
                    text: "A manually selected image stays until the desktop wallpaper changes again."
                    font.pixelSize: 11
                }
            }

            Card {
                Heading { text: "02  Palette & appearance" }
                Flow {
                    Layout.fillWidth: true; spacing: 8
                    Repeater {
                        model: ["dark", "light"]
                        ColorEditorButton {
                            required property string modelData
                            text: (ColorPaletteService.mode === modelData ? "✓  " : "") + (modelData === "dark" ? "Dark" : "Light")
                            prominent: ColorPaletteService.mode === modelData
                            enabled: !page.fixedPalette || modelData === "dark"
                            onClicked: ColorPaletteService.setMode(modelData)
                        }
                    }
                }
                Label { text: "Wallpaper palettes"; color: SettingsPalette.text; font.bold: true }
                GridLayout {
                    id: schemes
                    Layout.fillWidth: true
                    columns: width >= 780 ? 3 : width >= 460 ? 2 : 1
                    columnSpacing: 8; rowSpacing: 8
                    Repeater {
                        model: ColorPaletteService.availableTypes.filter(function(t) { return !ColorPaletteService.isStaticType(t); })
                        SchemeCard { }
                    }
                }
                Label { text: "Signature themes · fixed dark palettes"; color: SettingsPalette.text; font.bold: true }
                GridLayout {
                    Layout.fillWidth: true
                    columns: schemes.columns
                    columnSpacing: 8; rowSpacing: 8
                    Repeater {
                        model: ColorPaletteService.availableTypes.filter(function(t) { return ColorPaletteService.isStaticType(t); })
                        SchemeCard { }
                    }
                }
            }

            Card {
                visible: ColorPaletteService.enabled
                ModuleColorEditor { Layout.fillWidth: true }
            }
        }
    }

    component SchemeCard: Controls.AbstractButton {
        id: choice
        required property string modelData
        readonly property bool selected: ColorPaletteService.matugenType === modelData
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        implicitHeight: Math.max(90, choiceBody.implicitHeight + 24)
        padding: 12
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.name: ColorPaletteService.schemeLabel(modelData)
        Accessible.description: page.descriptions[modelData] + (selected ? " Selected." : "")
        onClicked: ColorPaletteService.setMatugenType(modelData)
        background: Rectangle {
            radius: 10
            color: choice.selected ? SettingsPalette.withAlpha(page.accent, 0.12)
                : choice.hovered ? SettingsPalette.cardStrong : SettingsPalette.background
            border.width: choice.activeFocus || choice.selected ? 2 : 1
            border.color: choice.activeFocus ? SettingsPalette.text : choice.selected ? page.accent : SettingsPalette.border
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        contentItem: ColumnLayout {
            id: choiceBody
            spacing: 5
            Label {
                text: (choice.selected ? "✓  " : "") + ColorPaletteService.schemeLabel(choice.modelData)
                color: SettingsPalette.text; font.bold: true; font.pixelSize: 13
            }
            Label { text: page.descriptions[choice.modelData] || ""; font.pixelSize: 11 }
        }
    }

    Platform.FileDialog {
        id: fileDialog
        title: "Choose a palette source"
        nameFilters: ["Images (*.jpg *.jpeg *.png *.webp)", "All files (*)"]
        folder: Platform.StandardPaths.writableLocation(Platform.StandardPaths.PicturesLocation)
        onAccepted: ColorPaletteService.selectWallpaper(decodeURIComponent(file.toString().replace("file://", "")))
    }
}
