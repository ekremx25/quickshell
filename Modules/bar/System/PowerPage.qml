import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"

Item {
    id: powerPage


    Process {
        id: powerProc
        command: []
        running: false
    }

    readonly property var actions: [
        { key: "shutdown",  icon: "⏻",  label: "Kapat",          desc: "Sistemi kapat",           color: "#f38ba8", cmd: ["systemctl", "poweroff"] },
        { key: "reboot",    icon: "󰜉", label: "Yeniden Başlat",  desc: "Sistemi yeniden başlat",  color: "#fab387", cmd: ["systemctl", "reboot"] },
        { key: "suspend",   icon: "󰒲", label: "Askıya Al",       desc: "Uyku moduna geç",         color: "#89b4fa", cmd: ["systemctl", "suspend"] },
        { key: "hibernate",  icon: "󰋊", label: "Hazırda Beklet",  desc: "Diske yaz ve kapat",      color: "#cba6f7", cmd: ["systemctl", "hibernate"] },
        { key: "logout",    icon: "󰍃", label: "Oturumu Kapat",   desc: "Masaüstünden çık",        color: "#94e2d5", cmd: ["niri", "msg", "action", "quit"] },
        { key: "lock",      icon: "󰌾", label: "Kilitle",         desc: "Ekranı kilitle",          color: "#a6adc8", cmd: ["loginctl", "lock-session"] }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Text { text: "⏻"; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
            Text { text: "Güç Seçenekleri"; font.bold: true; font.pixelSize: 18; color: Theme.text }
        }

        Item { height: 8 }

        // Butonlar grid
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 10

            Repeater {
                model: powerPage.actions

                Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    height: 80
                    radius: 12
                    color: pwMA.containsMouse
                        ? Qt.rgba(Qt.color(modelData.color).r, Qt.color(modelData.color).g, Qt.color(modelData.color).b, 0.15)
                        : Theme.surface
                    border.color: pwMA.containsMouse ? modelData.color : "transparent"
                    border.width: pwMA.containsMouse ? 1 : 0

                    Behavior on color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: modelData.icon
                            font.pixelSize: 24
                            font.family: "JetBrainsMono Nerd Font"
                            color: modelData.color
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: modelData.label
                            color: Theme.text
                            font.pixelSize: 12
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    MouseArea {
                        id: pwMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerProc.running = false;
                            powerProc.command = modelData.cmd;
                            powerProc.running = true;
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
