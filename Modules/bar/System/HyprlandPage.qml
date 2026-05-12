import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette

Item {
    id: page

    property int gapsIn: 6
    property int gapsOut: 3
    property int borderSize: 2
    property int rounding: 10
    property bool shadowEnabled: false
    property string palette: "solid"
    property string statusMessage: ""
    readonly property string applyScriptPath: (Quickshell.env("HOME") || "") + "/.config/quickshell/scripts/hypr_gaps_apply.sh"

    readonly property var presets: [
        { label: "Clean", inner: 4, outer: 2, border: 1, radius: 8, shadow: false, palette: "solid" },
        { label: "Balanced", inner: 6, outer: 3, border: 2, radius: 10, shadow: false, palette: "solid" },
        { label: "Airy", inner: 10, outer: 12, border: 2, radius: 14, shadow: false, palette: "catppuccin" },
        { label: "Focus", inner: 5, outer: 17, border: 2, radius: 10, shadow: false, palette: "aqua" }
    ]

    readonly property var palettes: [
        { key: "aqua", label: "Aqua", a: "#33ccff", b: "#00ff99" },
        { key: "catppuccin", label: "Catppuccin", a: "#89b4fa", b: "#cba6f7" },
        { key: "rose", label: "Rose", a: "#f5c2e7", b: "#f38ba8" },
        { key: "jade", label: "Jade", a: "#a6e3a1", b: "#94e2d5" },
        { key: "amber", label: "Amber", a: "#f9e2af", b: "#fab387" },
        { key: "mono", label: "Mono", a: "#cdd6f4", b: "#a6adc8" },
        { key: "solid", label: "Solid", a: "#89b4fa", b: "#89b4fa" }
    ]

    function clampInt(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, Math.round(value)))
    }

    function applyPreset(preset) {
        gapsIn = preset.inner
        gapsOut = preset.outer
        borderSize = preset.border
        rounding = preset.radius
        shadowEnabled = preset.shadow
        palette = preset.palette
        applySettings()
    }

    function applySettings() {
        applyProc.command = [applyScriptPath, String(gapsIn), String(gapsOut), String(borderSize), String(rounding), String(shadowEnabled), palette]
        applyProc.running = false
        applyProc.running = true
        statusMessage = "Applying..."
    }

    function loadCurrent() {
        loadProc.running = false
        loadProc.running = true
    }

    Component.onCompleted: loadCurrent()

    Process {
        id: loadProc
        command: [
            "bash",
            "-lc",
            "printf '%s %s %s %s %s\\n' " +
            "\"$(hyprctl getoption general:gaps_in | awk 'NR==1{print $NF}')\" " +
            "\"$(hyprctl getoption general:gaps_out | awk 'NR==1{print $NF}')\" " +
            "\"$(hyprctl getoption general:border_size | awk 'NR==1{print $2}')\" " +
            "\"$(hyprctl getoption decoration:rounding | awk 'NR==1{print $2}')\" " +
            "\"$(hyprctl getoption decoration:shadow:enabled | awk 'NR==1{print $2}')\""
        ]
        property string output: ""
        stdout: SplitParser { onRead: data => loadProc.output += data }
        onExited: {
            var parts = String(loadProc.output || "").trim().split(/\s+/)
            var nextIn = parseInt(parts[0])
            var nextOut = parseInt(parts[1])
            var nextBorder = parseInt(parts[2])
            var nextRadius = parseInt(parts[3])
            if (!isNaN(nextIn)) gapsIn = page.clampInt(nextIn, 0, 80)
            if (!isNaN(nextOut)) gapsOut = page.clampInt(nextOut, 0, 120)
            if (!isNaN(nextBorder)) borderSize = page.clampInt(nextBorder, 0, 12)
            if (!isNaN(nextRadius)) rounding = page.clampInt(nextRadius, 0, 40)
            shadowEnabled = parts[4] === "true"
            loadProc.output = ""
        }
    }

    Process {
        id: applyProc
        command: []
        property string err: ""
        stderr: SplitParser { onRead: data => applyProc.err += data + "\n" }
        onExited: exitCode => {
            if (exitCode === 0) {
                statusMessage = "Applied"
                loadCurrent()
            } else {
                statusMessage = applyProc.err.trim().length > 0 ? applyProc.err.trim() : "Apply failed"
            }
            applyProc.err = ""
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: mainColumn.implicitHeight + 40
        clip: true

        ColumnLayout {
            id: mainColumn
            width: parent.width
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Text { text: "󰖲"; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
                Text { text: "Hyprland"; font.bold: true; font.pixelSize: 18; color: SettingsPalette.text }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: luaText.implicitWidth + 22
                    height: 28
                    radius: 8
                    color: Qt.rgba(166 / 255, 227 / 255, 161 / 255, 0.12)
                    Text { id: luaText; anchors.centerIn: parent; text: "Lua"; color: SettingsPalette.text; font.pixelSize: 12; font.bold: true }
                }
            }

            Section {
                title: "Presets"
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: page.presets
                        Rectangle {
                            required property var modelData
                            Layout.preferredWidth: 180
                            height: 54
                            radius: 8
                            color: presetArea.containsMouse ? Qt.rgba(137 / 255, 180 / 255, 250 / 255, 0.16) : Qt.rgba(255, 255, 255, 0.04)
                            border.color: Qt.rgba(255, 255, 255, 0.08)
                            border.width: 1
                            Text { anchors.centerIn: parent; text: modelData.label; color: SettingsPalette.text; font.pixelSize: 13; font.bold: true }
                            MouseArea {
                                id: presetArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.applyPreset(modelData)
                            }
                        }
                    }
                }
            }

            Section {
                title: "Window Spacing"
                SliderControl { Layout.fillWidth: true; label: "Inner gap"; value: page.gapsIn; maximum: 80; accent: "#74c7ec"; onSetValue: value => page.gapsIn = page.clampInt(value, 0, 80) }
                SliderControl { Layout.fillWidth: true; label: "Outer gap"; value: page.gapsOut; maximum: 120; accent: "#f9e2af"; onSetValue: value => page.gapsOut = page.clampInt(value, 0, 120) }
                SliderControl { Layout.fillWidth: true; label: "Border size"; value: page.borderSize; maximum: 12; accent: "#cba6f7"; onSetValue: value => page.borderSize = page.clampInt(value, 0, 12) }
                SliderControl { Layout.fillWidth: true; label: "Corner radius"; value: page.rounding; maximum: 40; accent: "#a6e3a1"; onSetValue: value => page.rounding = page.clampInt(value, 0, 40) }
            }

            Section {
                title: "Effects"
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Shadow"; color: SettingsPalette.text; font.pixelSize: 13; font.bold: true }
                        Text { text: "Blur stays disabled. Shadow is optional."; color: SettingsPalette.subtext; font.pixelSize: 11 }
                    }
                    ToggleSwitch {
                        checked: page.shadowEnabled
                        onToggled: page.shadowEnabled = !page.shadowEnabled
                    }
                }
            }

            Section {
                title: "Border Palette"
                Flow {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: page.palettes
                        Rectangle {
                            required property var modelData
                            width: 196
                            height: 56
                            radius: 8
                            color: page.palette === modelData.key ? Qt.rgba(137 / 255, 180 / 255, 250 / 255, 0.18) : Qt.rgba(255, 255, 255, 0.04)
                            border.color: page.palette === modelData.key ? Theme.primary : Qt.rgba(255, 255, 255, 0.08)
                            border.width: page.palette === modelData.key ? 2 : 1
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10
                                Rectangle { width: 24; height: 24; radius: 12; color: modelData.a }
                                Rectangle { width: 24; height: 24; radius: 12; color: modelData.b }
                                Text { text: modelData.label; color: SettingsPalette.text; font.pixelSize: 13; font.bold: true }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.palette = modelData.key
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    Layout.fillWidth: true
                    height: 56
                    radius: 10
                    color: Qt.rgba(137 / 255, 180 / 255, 250 / 255, 0.08)
                    border.color: Qt.rgba(255, 255, 255, 0.07)
                    border.width: 1
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; text: page.statusMessage; color: Theme.primary; font.pixelSize: 12; font.bold: true }
                }

                Rectangle {
                    width: 156
                    height: 56
                    radius: 10
                    color: applyArea.containsMouse ? Qt.lighter(Theme.primary, 1.08) : Theme.primary
                    Text { anchors.centerIn: parent; text: "Apply"; color: "#1e1e2e"; font.pixelSize: 13; font.bold: true }
                    MouseArea {
                        id: applyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.applySettings()
                    }
                }
            }
        }
    }

    component Section: Rectangle {
        id: section
        property string title: ""
        default property alias content: sectionColumn.data
        Layout.fillWidth: true
        implicitHeight: sectionColumn.implicitHeight + 28
        radius: 10
        color: Qt.rgba(255, 255, 255, 0.045)
        border.color: Qt.rgba(255, 255, 255, 0.08)
        border.width: 1

        ColumnLayout {
            id: sectionColumn
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14
            Text {
                text: section.title
                color: SettingsPalette.text
                font.pixelSize: 15
                font.bold: true
            }
        }
    }

    component ToggleSwitch: Rectangle {
        id: toggle
        property bool checked: false
        signal toggled()
        width: 74
        height: 38
        radius: 19
        color: checked ? Qt.rgba(137 / 255, 180 / 255, 250 / 255, 0.45) : Qt.rgba(255, 255, 255, 0.10)
        Rectangle {
            width: 30
            height: 30
            radius: 15
            anchors.verticalCenter: parent.verticalCenter
            x: toggle.checked ? parent.width - width - 4 : 4
            color: "#f5f7fa"
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
        }
    }

    component SliderControl: ColumnLayout {
        id: control
        property string label: ""
        property int value: 0
        property int maximum: 100
        property color accent: Theme.primary
        signal setValue(int value)

        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text { text: control.label; color: SettingsPalette.subtext; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
            Text { text: control.value + " px"; color: control.accent; font.pixelSize: 12; font.bold: true }
        }

        Item {
            Layout.fillWidth: true
            height: 32

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 7
                radius: 4
                color: Qt.rgba(255, 255, 255, 0.08)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, control.value / Math.max(1, control.maximum)))
                    height: parent.height
                    radius: parent.radius
                    color: control.accent
                }
            }

            Rectangle {
                width: 20
                height: 20
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width * Math.max(0, Math.min(1, control.value / Math.max(1, control.maximum))) - 10
                color: "#f5f7fa"
                border.color: Qt.lighter(control.accent, 1.15)
                border.width: 2
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function setFromX(mx) {
                    var ratio = Math.max(0, Math.min(1, mx / width))
                    control.setValue(Math.round(ratio * control.maximum))
                }
                onPressed: function(mouse) { setFromX(mouse.x) }
                onPositionChanged: function(mouse) { if (pressed) setFromX(mouse.x) }
            }
        }
    }
}
