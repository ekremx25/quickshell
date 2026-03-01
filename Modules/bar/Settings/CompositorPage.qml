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
            Text { text: ""; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
            Text { text: "Compositor"; font.bold: true; font.pixelSize: 18; color: Theme.text }
        }

        // Niri info card
        Rectangle {
            Layout.fillWidth: true
            height: compositorInfo.height + 32
            radius: 12
            color: Qt.rgba(137/255, 180/255, 250/255, 0.08)
            border.color: Qt.rgba(137/255, 180/255, 250/255, 0.15)
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
                        color: Qt.rgba(137/255, 180/255, 250/255, 0.15)
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.pixelSize: 24
                            font.family: "JetBrainsMono Nerd Font"
                            color: Theme.primary
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Text { text: "Niri"; font.pixelSize: 18; font.bold: true; color: Theme.text }
                        Text { text: "Scrolling Tiling Wayland Compositor"; font.pixelSize: 12; color: Theme.overlay2 }
                    }

                    Item { Layout.fillWidth: true }
                    Rectangle { width: 12; height: 12; radius: 6; color: Theme.green }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

        // Details
        Text { text: "Details"; font.pixelSize: 14; font.bold: true; color: Theme.text }

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
                color: index % 2 === 0 ? Qt.rgba(255,255,255,0.02) : "transparent"

                RowLayout {
                    anchors.fill: parent; anchors.margins: 12
                    Text { text: modelData.label; font.pixelSize: 12; color: Theme.subtext; Layout.preferredWidth: 120 }
                    Text { text: modelData.value; font.pixelSize: 12; color: Theme.text; Layout.fillWidth: true; elide: Text.ElideMiddle }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

        // Connected Monitors
        Text { text: "Connected Monitors"; font.pixelSize: 14; font.bold: true; color: Theme.text; visible: CompositorService.monitors.length > 0 }

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
                        color: Qt.rgba(255,255,255,0.03)
                        border.color: Qt.rgba(255,255,255,0.06); border.width: 1

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 10

                            Rectangle {
                                width: 40; height: 40; radius: 8
                                color: Qt.rgba(203/255, 166/255, 247/255, 0.15)
                                Text { anchors.centerIn: parent; text: "󰍹"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
                            }

                            ColumnLayout {
                                spacing: 2; Layout.fillWidth: true
                                Text { text: modelData.name; font.pixelSize: 13; font.bold: true; color: Theme.text }
                                Text { text: modelData.make + " " + modelData.model + " — " + modelData.width + "×" + modelData.height + " @ " + modelData.refreshRate + "Hz"; font.pixelSize: 10; color: Theme.overlay2 }
                            }

                            Text { text: modelData.scale + "×"; font.pixelSize: 11; color: Theme.subtext }
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
                color: powerOnMA.containsMouse ? Qt.rgba(166/255, 227/255, 161/255, 0.15) : Qt.rgba(255,255,255,0.04)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { anchors.centerIn: parent; text: "Power On Monitors"; font.pixelSize: 12; color: Theme.green }
                MouseArea { id: powerOnMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: CompositorService.powerOnMonitors() }
            }

            Rectangle {
                Layout.fillWidth: true; height: 36; radius: 8
                color: powerOffMA.containsMouse ? Qt.rgba(243/255, 139/255, 168/255, 0.15) : Qt.rgba(255,255,255,0.04)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { anchors.centerIn: parent; text: "Power Off Monitors"; font.pixelSize: 12; color: Theme.red }
                MouseArea { id: powerOffMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: CompositorService.powerOffMonitors() }
            }
        }
    }
}
