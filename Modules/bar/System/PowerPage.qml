import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"
import "../../../Services" as S

Item {
    id: powerPage

    function logoutCommand() {
        if (S.CompositorService.isHyprland) return ["hyprctl", "dispatch", "exit"];
        if (S.CompositorService.isNiri) return ["niri", "msg", "action", "quit"];
        if (S.CompositorService.isMango) return ["mmsg", "dispatch", "quit"];
        const sessionId = Quickshell.env("XDG_SESSION_ID") || "";
        return sessionId ? ["loginctl", "terminate-session", sessionId] : ["false"];
    }


    Process {
        id: powerProc
        command: []
        running: false
    }

    readonly property var actions: [
        { key: "shutdown",  icon: "⏻",  label: "Shutdown",       desc: "Power off the system",    color: Theme.cpRed, cmd: ["systemctl", "poweroff"] },
        { key: "reboot",    icon: "󰜉", label: "Reboot",          desc: "Restart the system",      color: Theme.cpPeach, cmd: ["systemctl", "reboot"] },
        { key: "suspend",   icon: "󰒲", label: "Suspend",         desc: "Enter sleep mode",        color: Theme.cpBlue, cmd: ["systemctl", "suspend"] },
        { key: "hibernate", icon: "󰋊", label: "Hibernate",       desc: "Save to disk and power off", color: Theme.cpMauve, cmd: ["systemctl", "hibernate"] },
        { key: "logout",    icon: "󰍃", label: "Log Out",         desc: "End the desktop session", color: Theme.cpTeal, cmd: powerPage.logoutCommand() },
        { key: "lock",      icon: "󰌾", label: "Lock",            desc: "Lock the screen",         color: Theme.cpSubtext0, cmd: ["loginctl", "lock-session"] }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Text { text: "⏻"; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
            Text {  text: "Power Options"; font.bold: true; font.pixelSize: 18; color: SettingsPalette.text; font.family: Theme.fontFamily }
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
                        : SettingsPalette.surface
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
                            font.family: Theme.fontFamily
                            text: modelData.label
                            color: SettingsPalette.text
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
