import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"
import "../../../Services/core" as Core
import "../Settings/SettingsPalette.js" as SettingsPalette

Item {
    id: bluetoothPage

    // ── State ──────────────────────────────────────────────────────────────
    property bool powered: false
    property bool scanning: false
    property bool loading: true
    property var devices: []

    // ── Backend helpers ────────────────────────────────────────────────────
    function refresh() {
        if (!statusProc.running) {
            statusProc.out = ""
            statusProc.running = true
        }
    }

    function togglePower() {
        Quickshell.execDetached(["bluetoothctl", "power", powered ? "off" : "on"])
        refreshTimer.restart()
    }

    function connect(mac) {
        Quickshell.execDetached(["bluetoothctl", "connect", mac])
        refreshTimer.interval = 3000
        refreshTimer.restart()
    }

    function disconnect(mac) {
        Quickshell.execDetached(["bluetoothctl", "disconnect", mac])
        refreshTimer.interval = 1500
        refreshTimer.restart()
    }

    // ── Processes ──────────────────────────────────────────────────────────
    Process {
        id: statusProc
        command: [Core.PathService.configPath("Modules/bar/System/bt_status.sh")]
        running: true
        property string out: ""
        stdout: SplitParser { onRead: data => statusProc.out += data + "\n" }
        onExited: {
            var lines = statusProc.out.trim().split("\n")
            var devs = []
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (line.startsWith("POWERED=")) {
                    bluetoothPage.powered = line.substring(8).trim() === "yes"
                } else if (line.startsWith("DEVICE=")) {
                    var parts = line.substring(7).split("|")
                    if (parts.length >= 3) {
                        devs.push({
                            mac:       parts[0] || "",
                            name:      parts[1] || parts[0] || "Unknown",
                            connected: (parts[2] || "").trim() === "yes",
                            icon:      parts[3] || ""
                        })
                    }
                }
            }
            bluetoothPage.devices = devs
            bluetoothPage.loading = false
            statusProc.out = ""
        }
    }

    Timer {
        id: refreshTimer
        interval: 1500
        repeat: false
        onTriggered: bluetoothPage.refresh()
    }

    // ── UI ─────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // Title + power toggle
        RowLayout {
            Layout.fillWidth: true

            Text { text: "󰂯"; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
            Text {  text: "Bluetooth"; font.bold: true; font.pixelSize: 18; color: SettingsPalette.text; Layout.fillWidth: true; font.family: Theme.fontFamily }

            // Power toggle
            Rectangle {
                width: 52; height: 28; radius: 14
                color: bluetoothPage.powered ? Qt.rgba(137/255, 180/255, 250/255, 0.3) : Qt.rgba(255,255,255,0.08)
                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    width: 22; height: 22; radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    x: bluetoothPage.powered ? parent.width - width - 3 : 3
                    color: bluetoothPage.powered ? Theme.primary : SettingsPalette.subtext
                    Behavior on x { NumberAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bluetoothPage.togglePower()
                }
            }
        }

        // Off message
        Text {
            font.family: Theme.fontFamily
            visible: !bluetoothPage.powered && !bluetoothPage.loading
            text: "Bluetooth is off"
            color: SettingsPalette.subtext
            font.pixelSize: 13
            Layout.alignment: Qt.AlignHCenter
        }

        // Loading
        Text {
            font.family: Theme.fontFamily
            visible: bluetoothPage.loading
            text: "Loading..."
            color: SettingsPalette.subtext
            font.pixelSize: 13
            Layout.alignment: Qt.AlignHCenter
        }

        // Device list
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: bluetoothPage.powered && !bluetoothPage.loading

            Column {
                anchors.fill: parent
                spacing: 6

                // Title
                Text {
                    font.family: Theme.fontFamily
                    text: "Paired Devices"
                    color: SettingsPalette.subtext
                    font.pixelSize: 12
                    font.bold: true
                    bottomPadding: 4
                }

                // Empty list message
                Text {
                    font.family: Theme.fontFamily
                    visible: bluetoothPage.devices.length === 0
                    text: "No paired devices"
                    color: Qt.rgba(205/255, 214/255, 244/255, 0.4)
                    font.pixelSize: 13
                }

                // Device cards
                Repeater {
                    model: bluetoothPage.devices

                    Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 56
                        color: SettingsPalette.surface
                        radius: 10

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            // Icon
                            Rectangle {
                                width: 32; height: 32; radius: 8
                                color: modelData.connected
                                    ? Qt.rgba(137/255, 180/255, 250/255, 0.15)
                                    : Qt.rgba(255,255,255,0.05)
                                Text {
                                    anchors.centerIn: parent
                                    font.pixelSize: 16
                                    font.family: Theme.fontFamily
                                    color: modelData.connected ? Theme.primary : SettingsPalette.subtext
                                    text: {
                                        var ic = modelData.icon || ""
                                        if (ic.indexOf("audio") !== -1 || ic.indexOf("headset") !== -1 || ic.indexOf("headphone") !== -1) return "󰋋"
                                        if (ic.indexOf("input-gaming") !== -1) return "󰊗"
                                        if (ic.indexOf("phone") !== -1) return "󰄜"
                                        if (ic.indexOf("keyboard") !== -1) return "󰌌"
                                        if (ic.indexOf("mouse") !== -1) return "󰍽"
                                        return "󰂯"
                                    }
                                }
                            }

                            // Name + status
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    font.family: Theme.fontFamily
                                    text: modelData.name
                                    color: SettingsPalette.text
                                    font.bold: true
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    font.family: Theme.fontFamily
                                    text: modelData.connected ? "Connected" : "Paired"
                                    color: modelData.connected ? Theme.primary : SettingsPalette.subtext
                                    font.pixelSize: 11
                                }
                            }

                            // Connect / Disconnect button
                            Rectangle {
                                width: 80; height: 28; radius: 8
                                color: modelData.connected
                                    ? Qt.rgba(243/255, 139/255, 168/255, 0.15)
                                    : Qt.rgba(137/255, 180/255, 250/255, 0.15)
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    font.family: Theme.fontFamily
                                    anchors.centerIn: parent
                                    text: modelData.connected ? "Disconnect" : "Connect"
                                    color: modelData.connected ? "#f38ba8" : Theme.primary
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.connected)
                                            bluetoothPage.disconnect(modelData.mac)
                                        else
                                            bluetoothPage.connect(modelData.mac)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
