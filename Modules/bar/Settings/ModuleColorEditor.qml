import QtQuick
import "ColorPresets.js" as ColorPresets
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import QtQuick.Dialogs as Dialogs
import Quickshell.Io
import "../../../Widgets"
import "../../../Services"
import "../../../Services/core" as Core

ColumnLayout {
    id: editor
    spacing: 14
    property string selectedKey: "launcher"
    property string selectedName: "Launcher"
    property string selectedIcon: "󰣇"
    property string draft: String(Theme.launcherColor)
    property string pickerError: ""
    property var undoColors: null
    property bool showReadyPalette: false
    property string searchText: ""
    property bool customOnly: false
    readonly property var filteredModules: ColorPaletteService.colorModules.filter(function(module) {
        return (!editor.customOnly || !!ColorPaletteService.moduleAccentColors[module.key])
            && module.label.toLowerCase().indexOf(editor.searchText.trim().toLowerCase()) !== -1;
    })
    readonly property var readyColors: ColorPresets.create()
    readonly property bool valid: /^#[0-9a-fA-F]{6}$/.test(draft)
    readonly property color draftColor: valid ? draft : moduleColor(selectedKey)
    readonly property int customCount: Object.keys(ColorPaletteService.moduleAccentColors).length
    function moduleColor(key) {
        return Theme[key + "Color"];
    }
    function remember() {
        undoColors = JSON.parse(JSON.stringify(ColorPaletteService.moduleAccentColors));
    }
    readonly property color currentColor: moduleColor(selectedKey)
    readonly property bool dirty: valid && draft.toLowerCase() !== String(currentColor).toLowerCase()
    function saveSelection() {
        if (!valid)
            return;
        remember();
        ColorPaletteService.setModuleColor(selectedKey, draft);
    }
    function resetSelection() {
        remember();
        ColorPaletteService.setModuleColor(selectedKey, "");
        draft = String(currentColor);
    }
    function resetAll() {
        remember();
        ColorPaletteService.resetModuleColors();
        draft = String(currentColor);
    }
    function undo() {
        if (undoColors === null)
            return;
        ColorPaletteService.restoreModuleColors(undoColors);
        undoColors = null;
        draft = String(currentColor);
    }
    function choose(key, label, icon) {
        selectedKey = key;
        selectedName = label;
        selectedIcon = icon;
        draft = String(moduleColor(key));
        pickerError = "";
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.withAlpha(Theme.text, 0.1)
    }
    ColumnLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            Text {
                text: "03  Make it personal"
                color: SettingsPalette.text
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: editor.customCount + (editor.customCount === 1 ? " custom color" : " custom colors") + " · Other modules follow the palette"
                color: SettingsPalette.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            ColorEditorButton {
                text: "Undo"
                visible: editor.undoColors !== null
                enabled: !picker.running
                onClicked: editor.undo()
            }
            ColorEditorButton {
                text: "Use automatic colors"
                enabled: editor.customCount > 0 && !picker.running
                onClicked: editor.resetAll()
            }
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Choose a module to edit its accent. Custom colors stay when your wallpaper changes."
        color: SettingsPalette.subtext
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
    GridLayout {
        Layout.fillWidth: true
        columns: width >= 440 ? 2 : 1
        Controls.TextField {
            Layout.fillWidth: true
            implicitHeight: 38
            placeholderText: "Search modules…"
            Accessible.name: "Search module colors"
            color: SettingsPalette.text
            placeholderTextColor: SettingsPalette.subtext
            font.family: Theme.fontFamily
            font.pixelSize: 12
            selectByMouse: true
            onTextEdited: editor.searchText = text
            background: Rectangle {
                color: SettingsPalette.background; radius: 8
                border.color: parent.activeFocus ? SettingsPalette.text : SettingsPalette.border
            }
        }
        ColorEditorButton {
            text: editor.customOnly ? "✓  Custom colors only" : "All modules"
            prominent: editor.customOnly
            onClicked: editor.customOnly = !editor.customOnly
        }
    }
    Text {
        Layout.fillWidth: true
        visible: editor.filteredModules.length === 0
        text: "No matching modules. Change the search or show all modules."
        wrapMode: Text.WordWrap
        color: SettingsPalette.subtext
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
    GridLayout {
        Layout.fillWidth: true
        columns: Math.max(1, Math.min(4, Math.floor(width / 185)))
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: editor.filteredModules
            Rectangle {
                id: tile
                required property var modelData
                readonly property color moduleTint: editor.moduleColor(modelData.key)
                readonly property bool selected: editor.selectedKey === modelData.key
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label + (selected ? ", selected" : "")
                function selectModule() {
                    if (!picker.running) editor.choose(modelData.key, modelData.label, modelData.icon);
                }
                Keys.onReturnPressed: selectModule()
                Keys.onSpacePressed: selectModule()
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: 10
                color: Theme.withAlpha(Theme.text, tile.selected ? 0.10 : tileMouse.containsMouse ? 0.07 : 0.03)
                border.width: tile.selected || tile.activeFocus ? 2 : 1
                border.color: tile.activeFocus ? SettingsPalette.text : tile.selected ? SettingsPalette.readableAccent(tile.moduleTint) : Theme.withAlpha(Theme.text, 0.1)
                Behavior on color { ColorAnimation { duration: 140 } }
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 9
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 9
                        color: tile.moduleTint
                        Text {
                            anchors.centerIn: parent
                            text: tile.modelData.icon
                            color: Theme.foregroundFor(tile.moduleTint)
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 16
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: (tile.selected ? "✓ " : "") + tile.modelData.label
                            color: SettingsPalette.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: tile.selected
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: ColorPaletteService.moduleAccentColors[tile.modelData.key] ? "Custom · " + String(tile.moduleTint).toUpperCase() : "Automatic · " + String(tile.moduleTint).toUpperCase()
                            color: SettingsPalette.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                        }
                    }
                }
                MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !picker.running
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { tile.forceActiveFocus(Qt.MouseFocusReason); tile.selectModule(); }
                }
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: detail.implicitHeight + 28
        radius: 12
        color: Theme.withAlpha(Theme.text, 0.04)
        border.width: 1
        border.color: Theme.withAlpha(Theme.text, 0.12)
        ColumnLayout {
            id: detail
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 14
            }
            spacing: 12
            GridLayout {
                Layout.fillWidth: true
                columns: width >= 440 ? 3 : 1
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "Editing: " + editor.selectedName
                    color: SettingsPalette.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    text: "Preview"
                    color: SettingsPalette.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
                Rectangle {
                    implicitWidth: sample.implicitWidth + 28
                    implicitHeight: 36
                    radius: 18
                    color: editor.draftColor
                    Text {
                        id: sample
                        anchors.centerIn: parent
                        text: editor.selectedIcon + "  " + editor.selectedName
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.foregroundFor(editor.draftColor)
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Current: " + String(editor.moduleColor(editor.selectedKey)).toUpperCase() + "   →   Selected: " + editor.draft.toUpperCase() + (editor.dirty ? " · Unsaved" : " · Applied")
                color: SettingsPalette.text
                font.family: Theme.monoFontFamily
                font.pixelSize: 11
            }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    width: Math.min(parent.width, currentLabel.implicitWidth + 24)
                    height: 38
                    radius: 8
                    color: editor.moduleColor(editor.selectedKey)
                    Text {
                        id: currentLabel
                        anchors.centerIn: parent
                        width: parent.width - 24
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        text: editor.selectedIcon + "  " + editor.selectedName + " · Current " + String(editor.moduleColor(editor.selectedKey)).toUpperCase()
                        color: Theme.foregroundFor(parent.color)
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 11
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !picker.running
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editor.draft = String(editor.moduleColor(editor.selectedKey))
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Choose from presets or wallpaper samples. Your current color may not appear in either palette."
                color: SettingsPalette.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
            ColorEditorButton {
                text: editor.showReadyPalette ? "Hide preset palette ▴" : "Show 72-color palette ▾"
                enabled: !picker.running
                onClicked: editor.showReadyPalette = !editor.showReadyPalette
            }
            ColumnLayout {
                visible: editor.showReadyPalette
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: editor.selectedName + ": each column is a hue, with shades from dark to light. The last row contains grayscale colors."
                    color: SettingsPalette.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
                GridLayout {
                    columns: 12
                    columnSpacing: 5
                    rowSpacing: 5
                    Layout.fillWidth: true
                    Layout.maximumWidth: 650
                    Repeater {
                        model: editor.readyColors
                        ColorSwatch {
                            id: presetSwatch
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            Layout.minimumWidth: 12
                            swatchColor: presetSwatch.modelData.color
                            label: presetSwatch.modelData.name
                            selected: presetSwatch.modelData.color.toLowerCase() === editor.draft.toLowerCase()
                            enabled: !picker.running
                            onClicked: editor.draft = presetSwatch.modelData.color
                        }
                    }
                }
                Text {
                    text: "Selected: " + editor.draft.toUpperCase() + " · Click Save color to apply"
                    color: SettingsPalette.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
            Text {
                text: "Wallpaper samples"
                color: SettingsPalette.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
            Flow {
                Layout.fillWidth: true
                spacing: 7
                Repeater {
                    model: ColorPaletteService.spectrumColors.length ? ColorPaletteService.spectrumColors : [ColorPaletteService.primaryColor, ColorPaletteService.secondaryColor, ColorPaletteService.tertiaryColor]
                    ColorSwatch {
                        id: wallpaperSwatch
                        required property var modelData
                        width: 38
                        height: 38
                        swatchColor: wallpaperSwatch.modelData
                        label: "Wallpaper sample"
                        selected: String(wallpaperSwatch.modelData).toLowerCase() === editor.draft.toLowerCase()
                        enabled: !picker.running
                        onClicked: editor.draft = String(wallpaperSwatch.modelData)
                    }
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Controls.TextField {
                    width: 115
                    height: 36
                    text: editor.draft
                    maximumLength: 7
                    color: SettingsPalette.text
                    font.family: Theme.monoFontFamily
                    font.pixelSize: 12
                    placeholderText: "#RRGGBB"
                    selectByMouse: true
                    enabled: !picker.running
                    onTextEdited: editor.draft = text
                    background: Rectangle {
                        radius: 8
                        color: Theme.withAlpha(Theme.text, 0.04)
                        border.color: editor.valid ? Theme.withAlpha(Theme.text, 0.2) : SettingsPalette.readableAccent(Theme.red)
                        border.width: 1
                    }
                }
                ColorEditorButton {
                    text: "Advanced color picker"
                    prominent: false
                    enabled: !picker.running
                    onClicked: {
                        dialog.selectedColor = editor.draftColor;
                        dialog.open();
                    }
                }
                ColorEditorButton {
                    text: picker.running ? "Click screen · Esc to cancel" : "Pick from screen"
                    enabled: !picker.running
                    onClicked: {
                        editor.pickerError = "";
                        picker.output = "";
                        picker.running = true;
                    }
                }
                ColorEditorButton {
                    text: "Save color"
                    prominent: true
                    enabled: editor.valid && editor.dirty && !picker.running
                    onClicked: editor.saveSelection()
                }
                ColorEditorButton {
                    text: "Automatic"
                    enabled: !!ColorPaletteService.moduleAccentColors[editor.selectedKey] && !picker.running
                    onClicked: editor.resetSelection()
                }
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: editor.valid ? "Icon and text contrast is automatic. Changes apply only when you save." : "Enter a six-digit hex color, such as #39A5E8."
                color: SettingsPalette.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
            Text {
                visible: editor.pickerError !== ""
                text: editor.pickerError
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: SettingsPalette.readableAccent(Theme.red)
                font.pixelSize: 11
            }
        }
    }
    Dialogs.ColorDialog {
        id: dialog
        objectName: "moduleColorDialog"
        parentWindow: editor.Window.window
        popupType: Controls.Popup.Item
        title: editor.selectedName + " · Choose accent color"
        options: Dialogs.ColorDialog.DontUseNativeDialog
        onAccepted: editor.draft = String(selectedColor)
    }
    Process {
        id: picker
        property string output: ""
        command: ["bash", Core.PathService.configPath("scripts/pick-screen-color.sh")]
        stdout: StdioCollector {
            onStreamFinished: picker.output = text.trim()
        }
        onExited: function (code, status) {
            if (code === 0 && /^#[0-9a-fA-F]{6}$/.test(output))
                editor.draft = output;
            else if (code !== 2)
                editor.pickerError = "Could not pick a screen color. Try again or enter a hex code.";
        }
    }
}
