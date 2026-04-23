import QtQuick
import QtQuick.Layouts
import "SettingsPalette.js" as SettingsPalette
import Quickshell
import Qt.labs.platform
import "../../../Widgets"
import "../../../Services"
import "../../../Services/core/Log.js" as Log

Item {
    id: layoutPage

    property string presetsDir: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/presets/"
    property string barConfigPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/bar_config.json"
    property string activePreset: ""

    signal presetApplied()

    readonly property var presets: [
        { key: "macos", name: "macOS", icon: "", desc: "Left: Launcher, Calendar | Center: Workspaces | Right: Volume, Tray, Clock" },
        { key: "windows11", name: "Windows 11", icon: "", desc: "Left: Workspaces | Center: Launcher, Tray, Clock | Right: Volume, Notifications" },
        { key: "gnome", name: "GNOME", icon: "", desc: "Left: Calendar | Center: Clock | Right: Volume, Power, Tray" },
        { key: "kde", name: "KDE Plasma", icon: "", desc: "Left: Launcher, Workspaces | Center: (empty) | Right: Tray, Clock, Volume, Power" },
        { key: "zorin", name: "ZorinOS", icon: "", desc: "Left: Launcher, Calendar | Center: Clock | Right: Tray, Volume, Notifications, Power" },
        { key: "unity", name: "Unity", icon: "", desc: "Left: Launcher, Workspaces, Calendar | Center: Clock | Right: Volume, Tray, Power" },
        { key: "custom", name: "Custom", icon: "", desc: "Your saved custom layout" }
    ]

    FileCopyAction {
        id: presetCopyAction
        onFinished: success => {
            if (!success) return;
            layoutPage.activePreset = applyPendingPreset;
            layoutPage.presetApplied();
            Log.debug("LayoutPage", "Applied preset: " + applyPendingPreset);
        }
    }

    FileCopyAction {
        id: saveCustomAction
        onFinished: success => {
            if (!success) return;
            layoutPage.activePreset = "custom";
            Log.debug("LayoutPage", "Saved current layout as custom");
        }
    }

    property string applyPendingPreset: ""

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
                Text { text: ""; font.pixelSize: 20; font.family: Theme.fontFamily; color: Theme.primary }
                Text {  text: "Layout Presets"; font.bold: true; font.pixelSize: 18; color: SettingsPalette.text; font.family: Theme.fontFamily }
                Item { Layout.fillWidth: true }
            }

            Text {
                font.family: Theme.fontFamily
                text: "Select a preset to change your bar layout. Your current config will be overwritten."
                color: SettingsPalette.overlay2
                font.pixelSize: 12
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            // Save current as custom
            Rectangle {
                Layout.fillWidth: true
                height: 38
                radius: 10
                color: saveCustMA.containsMouse ? Qt.rgba(255,255,255,0.08) : Qt.rgba(255,255,255,0.04)
                border.color: SettingsPalette.surface
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8
                    Text {  text: "💾"; font.pixelSize: 14; font.family: Theme.fontFamily }
                    Text {  text: "Save current layout as Custom"; color: SettingsPalette.text; font.pixelSize: 13; font.family: Theme.fontFamily }
                }

                MouseArea {
                    id: saveCustMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: saveCurrentAsCustom()
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: SettingsPalette.surface }

            // Preset grid
            GridLayout {
                Layout.fillWidth: true
                // Removed Layout.fillHeight: true to let it grow with content inside Flickable
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                Repeater {
                    model: layoutPage.presets

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 90
                        radius: 12
                        color: {
                            if (layoutPage.activePreset === modelData.key) return Qt.rgba(137/255, 180/255, 250/255, 0.15);
                            if (presetMA.containsMouse) return Qt.rgba(255,255,255,0.06);
                            return Qt.rgba(255,255,255,0.03);
                        }
                        border.color: layoutPage.activePreset === modelData.key ? Theme.primary : Qt.rgba(255,255,255,0.06)
                        border.width: layoutPage.activePreset === modelData.key ? 2 : 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            RowLayout {
                                spacing: 8
                                Text {
                                    text: modelData.icon
                                    font.pixelSize: 20
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: layoutPage.activePreset === modelData.key ? Theme.primary : SettingsPalette.subtext
                                }
                                Text {
                                    font.family: Theme.fontFamily
                                    text: modelData.name
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: layoutPage.activePreset === modelData.key ? SettingsPalette.text : SettingsPalette.subtext
                                }

                                Item { Layout.fillWidth: true }

                                // Active indicator
                                Rectangle {
                                    visible: layoutPage.activePreset === modelData.key
                                    width: 8; height: 8; radius: 4
                                    color: Theme.green
                                }
                            }

                            Text {
                                font.family: Theme.fontFamily
                                text: modelData.desc
                                font.pixelSize: 10
                                color: SettingsPalette.overlay2
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: presetMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: applyPreset(modelData.key)
                        }
                    }
                }
            }
        }
    }

    // Apply preset
    function applyPreset(presetKey) {
        layoutPage.activePreset = presetKey; // Optimistic update
        applyPendingPreset = presetKey;
        Log.debug("LayoutPage", "Applying preset: " + presetKey);
        presetCopyAction.run(presetsDir + presetKey + ".json", barConfigPath);
    }

    // Save current config as custom
    function saveCurrentAsCustom() {
        saveCustomAction.run(barConfigPath, presetsDir + "custom.json");
    }
}
