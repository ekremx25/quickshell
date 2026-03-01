import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"
import "../../../Services"

Item {
    id: vpnPage

    signal openAddVpn()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "󰦝"; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
            Text { text: "VPN Management"; font.bold: true; font.pixelSize: 18; color: Theme.text }
            Item { Layout.fillWidth: true }

            // Status indicator
            Rectangle {
                width: statusRow.width + 16; height: 28; radius: 14
                color: VpnService.connected ? Qt.rgba(166/255, 227/255, 161/255, 0.15) : Qt.rgba(255,255,255,0.05)

                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle { width: 8; height: 8; radius: 4; color: VpnService.connected ? Theme.green : Theme.overlay2 }
                    Text {
                        text: VpnService.connected ? VpnService.activeName : "Disconnected"
                        font.pixelSize: 11
                        color: VpnService.connected ? Theme.green : Theme.subtext
                    }
                }
            }
        }

        // Error message
        Rectangle {
            visible: VpnService.errorMessage.length > 0
            Layout.fillWidth: true
            height: 36; radius: 8
            color: Qt.rgba(243/255, 139/255, 168/255, 0.15)
            Text {
                anchors.centerIn: parent
                text: "⚠ " + VpnService.errorMessage
                font.pixelSize: 12
                color: Theme.red
            }
        }

        // Add VPN button
        Rectangle {
            Layout.fillWidth: true
            height: 42; radius: 10
            color: addVpnMA.containsMouse ? Qt.lighter(Theme.primary, 1.2) : Theme.primary
            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                Text { text: "+"; font.pixelSize: 16; font.bold: true; color: "#1e1e2e" }
                Text { text: "Add VPN Connection"; font.pixelSize: 13; font.bold: true; color: "#1e1e2e" }
            }

            MouseArea {
                id: addVpnMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: vpnPage.openAddVpn()
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

        // Single VPN mode toggle
        Rectangle {
            Layout.fillWidth: true
            height: 40; radius: 8
            color: Qt.rgba(255,255,255,0.03)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text { text: "Single VPN mode"; color: Theme.text; font.pixelSize: 13 }
                Text { text: "(disconnect others when connecting)"; color: Theme.overlay2; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 44; height: 24; radius: 12
                    color: VpnService.singleActive ? Theme.primary : Qt.rgba(255,255,255,0.1)
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Rectangle {
                        width: 18; height: 18; radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        x: VpnService.singleActive ? parent.width - width - 3 : 3
                        color: "white"
                        Behavior on x { NumberAnimation { duration: 200 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: VpnService.singleActive = !VpnService.singleActive
                    }
                }
            }
        }

        // Profile list
        Text {
            text: VpnService.profiles.length > 0 ? "VPN Profiles (" + VpnService.profiles.length + ")" : "No VPN profiles configured"
            font.pixelSize: 13
            font.bold: VpnService.profiles.length > 0
            color: VpnService.profiles.length > 0 ? Theme.text : Theme.overlay2
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: profileColumn.height
            clip: true

            ColumnLayout {
                id: profileColumn
                width: parent.width
                spacing: 6

                Repeater {
                    model: VpnService.profiles

                    Rectangle {
                        Layout.fillWidth: true
                        height: 56; radius: 10
                        color: {
                            if (VpnService.isActiveUuid(modelData.uuid)) return Qt.rgba(166/255, 227/255, 161/255, 0.08);
                            if (profileMA.containsMouse) return Qt.rgba(255,255,255,0.06);
                            return Qt.rgba(255,255,255,0.03);
                        }
                        border.color: VpnService.isActiveUuid(modelData.uuid) ? Qt.rgba(166/255, 227/255, 161/255, 0.3) : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            // Type icon
                            Rectangle {
                                width: 32; height: 32; radius: 8
                                color: Qt.rgba(137/255, 180/255, 250/255, 0.15)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.type === "wireguard" ? "󰖂" : "󰦝"
                                    font.pixelSize: 16
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: Theme.primary
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.name
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.text
                                }
                                Text {
                                    text: modelData.type.toUpperCase() + (modelData.autoconnect ? " • Autoconnect" : "")
                                    font.pixelSize: 10
                                    color: Theme.overlay2
                                }
                            }

                            // Connect/Disconnect toggle
                            Rectangle {
                                width: 80; height: 30; radius: 8
                                color: {
                                    if (VpnService.isBusy) return Qt.rgba(255,255,255,0.05);
                                    if (VpnService.isActiveUuid(modelData.uuid)) return Qt.rgba(243/255, 139/255, 168/255, 0.2);
                                    return Qt.rgba(166/255, 227/255, 161/255, 0.2);
                                }
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: VpnService.isBusy ? "..." : (VpnService.isActiveUuid(modelData.uuid) ? "Disconnect" : "Connect")
                                    font.pixelSize: 11
                                    color: VpnService.isActiveUuid(modelData.uuid) ? Theme.red : Theme.green
                                }

                                MouseArea {
                                    id: profileMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: VpnService.isBusy ? Qt.BusyCursor : Qt.PointingHandCursor
                                    onClicked: {
                                        if (!VpnService.isBusy) VpnService.toggle(modelData.uuid);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Disconnect all
        Rectangle {
            visible: VpnService.connected
            Layout.fillWidth: true
            height: 36; radius: 8
            color: disconnectAllMA.containsMouse ? Qt.rgba(243/255, 139/255, 168/255, 0.2) : Qt.rgba(243/255, 139/255, 168/255, 0.1)
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "Disconnect All VPNs"
                font.pixelSize: 12
                color: Theme.red
            }

            MouseArea {
                id: disconnectAllMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: VpnService.disconnectAllActive()
            }
        }
    }
}
