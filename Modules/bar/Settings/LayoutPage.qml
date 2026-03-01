import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Qt.labs.platform
import "../../../Widgets"
import "../../../Services"

Item {
    id: layoutPage

    property string presetsDir: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/presets/"
    property string barConfigPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/bar_config.json"
    property string activePreset: ""

    signal presetApplied()

    readonly property var presets: [
        { key: "macos", name: "macOS", icon: "", desc: "Sol: Launcher, Calendar | Orta: Workspaces | Sağ: Volume, Tray, Clock" },
        { key: "windows11", name: "Windows 11", icon: "", desc: "Sol: Workspaces | Orta: Launcher, Tray, Clock | Sağ: Volume, Notifications" },
        { key: "gnome", name: "GNOME", icon: "", desc: "Sol: Calendar | Orta: Clock | Sağ: Volume, Power, Tray" },
        { key: "kde", name: "KDE Plasma", icon: "", desc: "Sol: Launcher, Workspaces | Orta: (boş) | Sağ: Tray, Clock, Volume, Power" },
        { key: "zorin", name: "ZorinOS", icon: "", desc: "Sol: Launcher, Calendar | Orta: Clock | Sağ: Tray, Volume, Notifications, Power" },
        { key: "unity", name: "Unity", icon: "", desc: "Sol: Launcher, Workspaces, Calendar | Orta: Clock | Sağ: Volume, Tray, Power" },
        { key: "custom", name: "Custom", icon: "", desc: "Your saved custom layout" }
    ]

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
                Text { text: "Layout Presets"; font.bold: true; font.pixelSize: 18; color: Theme.text }
                Item { Layout.fillWidth: true }
            }

            Text {
                text: "Select a preset to change your bar layout. Your current config will be overwritten."
                color: Theme.overlay2
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
                border.color: Theme.surface
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8
                    Text { text: "💾"; font.pixelSize: 14 }
                    Text { text: "Save current layout as Custom"; color: Theme.text; font.pixelSize: 13 }
                }

                MouseArea {
                    id: saveCustMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: saveCurrentAsCustom()
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

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
                                    color: layoutPage.activePreset === modelData.key ? Theme.primary : Theme.subtext
                                }
                                Text {
                                    text: modelData.name
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: layoutPage.activePreset === modelData.key ? Theme.text : Theme.subtext
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
                                text: modelData.desc
                                font.pixelSize: 10
                                color: Theme.overlay2
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
        applyProc.presetKey = presetKey;
        console.log("[LayoutPage] Applying preset: " + presetKey);
        applyProc.command = ["bash", "-c", "cp " + presetsDir + presetKey + ".json " + barConfigPath];
        applyProc.running = true;
    }

    Process {
        id: applyProc
        property string presetKey: ""
        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                layoutPage.activePreset = applyProc.presetKey;
                layoutPage.presetApplied();
                console.log("[LayoutPage] Applied preset: " + applyProc.presetKey);
            }
        }
    }

    // Save current config as custom
    function saveCurrentAsCustom() {
        saveCustomProc.command = ["bash", "-c", "cp " + barConfigPath + " " + presetsDir + "custom.json"];
        saveCustomProc.running = true;
    }

    Process {
        id: saveCustomProc
        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                layoutPage.activePreset = "custom";
                console.log("[LayoutPage] Saved current layout as custom");
            }
        }
    }
}
