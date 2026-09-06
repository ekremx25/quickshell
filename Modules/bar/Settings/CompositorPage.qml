import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"
import "../../../Services"

Item {
    id: compositorPage

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: ""; font.pixelSize: 20; font.family: Theme.fontFamily; color: SettingsPalette.readableAccent(Theme.primary) }
            Text {  text: "Compositor"; font.bold: true; font.pixelSize: 18; color: SettingsPalette.text; font.family: Theme.fontFamily }
        }

        // Niri info card
        Rectangle {
            Layout.fillWidth: true
            height: compositorInfo.height + 32
            radius: 12
            color: Theme.withAlpha(Theme.primary, 0.08)
            border.color: Theme.withAlpha(Theme.primary, 0.15)
            border.width: 1

            ColumnLayout {
                id: compositorInfo
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    spacing: 12
                    Rectangle {
                        width: 48; height: 48; radius: 12
                        color: Theme.withAlpha(Theme.primary, 0.15)
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.pixelSize: 24
                            font.family: Theme.fontFamily
                            color: SettingsPalette.readableAccent(Theme.primary)
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {  text: "Niri"; font.pixelSize: 18; font.bold: true; color: SettingsPalette.text; font.family: Theme.fontFamily }
                        Text {  text: "Scrolling Tiling Wayland Compositor"; font.pixelSize: 12; color: SettingsPalette.overlay2; font.family: Theme.fontFamily }
                    }

                    Item { Layout.fillWidth: true }
                    Rectangle { width: 12; height: 12; radius: 6; color: SettingsPalette.readableAccent(Theme.green) }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: SettingsPalette.surface }

        // Details
        Text {  text: "Details"; font.pixelSize: 14; font.bold: true; color: SettingsPalette.text; font.family: Theme.fontFamily }

        Repeater {
            model: [
                { label: "Compositor", value: "Niri" },
                { label: "Type", value: "Scrolling tiling WM" },
                { label: "Protocol", value: "Wayland" },
                { label: "Socket", value: CompositorService.niriSocket || "N/A" },
                { label: "Monitors", value: String(CompositorService.monitors.length) }
            ]

            Rectangle {
                Layout.fillWidth: true
                height: 36; radius: 8
                color: index % 2 === 0 ? Theme.withAlpha(Theme.text, 0.02) : "transparent"

                RowLayout {
                    anchors.fill: parent; anchors.margins: 12
                    Text {  text: modelData.label; font.pixelSize: 12; color: SettingsPalette.subtext; Layout.preferredWidth: 120; font.family: Theme.fontFamily }
                    Text {  text: modelData.value; font.pixelSize: 12; color: SettingsPalette.text; Layout.fillWidth: true; elide: Text.ElideMiddle; font.family: Theme.fontFamily }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: SettingsPalette.surface }

        // Connected Monitors
        Text {  text: "Connected Monitors"; font.pixelSize: 14; font.bold: true; color: SettingsPalette.text; visible: CompositorService.monitors.length > 0; font.family: Theme.fontFamily }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: monitorCol.height
            clip: true

            ColumnLayout {
                id: monitorCol
                width: parent.width
                spacing: 8

                Repeater {
                    model: CompositorService.monitors

                    Rectangle {
                        Layout.fillWidth: true
                        height: 64; radius: 10
                        color: Theme.withAlpha(Theme.text, 0.03)
                        border.color: Theme.withAlpha(Theme.text, 0.06); border.width: 1

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 10

                            Rectangle {
                                width: 40; height: 40; radius: 8
                                color: Theme.withAlpha(Theme.mauve, 0.15)
                                Text { anchors.centerIn: parent; text: "󰍹"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"; color: SettingsPalette.readableAccent(Theme.primary) }
                            }

                            ColumnLayout {
                                spacing: 2; Layout.fillWidth: true
                                Text {  text: modelData.name; font.pixelSize: 13; font.bold: true; color: SettingsPalette.text; font.family: Theme.fontFamily }
                                Text {  text: modelData.make + " " + modelData.model + " — " + modelData.width + "×" + modelData.height + " @ " + modelData.refreshRate + "Hz"; font.pixelSize: 10; color: SettingsPalette.overlay2; font.family: Theme.fontFamily }
                            }

                            Text {  text: modelData.scale + "×"; font.pixelSize: 11; color: SettingsPalette.subtext; font.family: Theme.fontFamily }
                        }
                    }
                }
            }
        }

        // Power controls
        RowLayout {
            Layout.fillWidth: true; spacing: 8

            Rectangle {
                Layout.fillWidth: true; height: 36; radius: 8
                color: powerOnMA.containsMouse ? Theme.withAlpha(Theme.green, 0.15) : Theme.withAlpha(Theme.text, 0.04)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {  anchors.centerIn: parent; text: "Power On Monitors"; font.pixelSize: 12; color: SettingsPalette.readableAccent(Theme.green); font.family: Theme.fontFamily }
                MouseArea { id: powerOnMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: CompositorService.powerOnMonitors() }
            }

            Rectangle {
                Layout.fillWidth: true; height: 36; radius: 8
                color: powerOffMA.containsMouse ? Theme.withAlpha(Theme.red, 0.15) : Theme.withAlpha(Theme.text, 0.04)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {  anchors.centerIn: parent; text: "Power Off Monitors"; font.pixelSize: 12; color: SettingsPalette.readableAccent(Theme.red); font.family: Theme.fontFamily }
                MouseArea { id: powerOffMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: CompositorService.powerOffMonitors() }
            }
        }
    }
}
