import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"
import "../../../Services"

Item {
    id: aboutPage

    property string quickshellVersion: ""
    property string systemInfo: ""

    Component.onCompleted: {
        versionProc.running = true;
        systemProc.running = true;
    }

    Process {
        id: versionProc
        command: ["quickshell", "--version"]
        running: false
        property string buf: ""
        stdout: SplitParser { onRead: data => { versionProc.buf += data; } }
        onExited: { aboutPage.quickshellVersion = versionProc.buf.trim() || "Unknown"; versionProc.buf = ""; }
    }

    Process {
        id: systemProc
        command: ["sh", "-c", "cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"' || echo 'Unknown OS'"]
        running: false
        property string buf: ""
        stdout: SplitParser { onRead: data => { systemProc.buf += data; } }
        onExited: { aboutPage.systemInfo = systemProc.buf.trim() || "Unknown"; systemProc.buf = ""; }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: layout.implicitHeight
        clip: true

        ColumnLayout {
            id: layout
            width: parent.width
            anchors.margins: 16
            spacing: 16

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { text: ""; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
                Text { text: "About"; font.bold: true; font.pixelSize: 18; color: Theme.text }
            }

            // Logo / branding
            Rectangle {
                Layout.fillWidth: true
                height: 120; radius: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(137/255, 180/255, 250/255, 0.15) }
                    GradientStop { position: 1.0; color: Qt.rgba(203/255, 166/255, 247/255, 0.1) }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "⚙"
                        font.pixelSize: 36
                        color: Theme.primary
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: "Quickshell Config"
                        font.pixelSize: 18; font.bold: true
                        color: Theme.text
                        Layout.alignment: Qt.AlignHCenter
                    }

                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

            // Info rows
            Repeater {
                model: [
                    { label: "Quickshell",    value: aboutPage.quickshellVersion, icon: "" },
                    { label: "OS",            value: aboutPage.systemInfo, icon: "󰌽" },
                    { label: "Compositor",    value: CompositorService.getInfoString(), icon: "" },
                    { label: "Theme",         value: Theme.currentThemeName || "Default", icon: "" },
                    { label: "Config Path",   value: "~/.config/quickshell/", icon: "󰉋" },
                    { label: "Screens",       value: String(Quickshell.screens.length) + " connected", icon: "󰍹" },
                    { label: "VPN",           value: VpnService.connected ? VpnService.activeName : "Not connected", icon: "󰦝" },
                    { label: "Material You",  value: ColorPaletteService.available ? (ColorPaletteService.enabled ? "Enabled" : "Disabled") : "Not available", icon: "" },
                    { label: "matugen",       value: ColorPaletteService.available ? "Installed" : "Not installed", icon: "" }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    height: 42; radius: 8
                    color: index % 2 === 0 ? Qt.rgba(255,255,255,0.02) : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 14
                        spacing: 10

                        Text {
                            text: modelData.icon
                            font.pixelSize: 14
                            font.family: "JetBrainsMono Nerd Font"
                            color: Theme.primary
                            Layout.preferredWidth: 20
                        }
                        Text {
                            text: modelData.label
                            font.pixelSize: 12; font.bold: true
                            color: Theme.subtext
                            Layout.preferredWidth: 120
                        }
                        Text {
                            text: modelData.value
                            font.pixelSize: 12
                            color: Theme.text
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
