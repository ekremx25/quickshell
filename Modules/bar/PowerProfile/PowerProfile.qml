import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../Widgets"

Rectangle {
    id: root

    implicitWidth: layout.implicitWidth + 24
    implicitHeight: 34
    radius: 17
    color: Theme.powerProfileColor

    Behavior on color { ColorAnimation { duration: 200 } }

    property string currentProfile: "balanced"
    property bool available: true

    readonly property var profileData: ({
        "performance": { icon: "󰓅", label: "Performans", color: "#f38ba8" },
        "balanced":    { icon: "󰾅", label: "Dengeli",    color: Theme.powerProfileColor },
        "power-saver": { icon: "󰾆", label: "Tasarruf",   color: "#a6e3a1" }
    })

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: {
                var data = root.profileData[root.currentProfile]
                return data ? data.icon : "󰾅"
            }
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
            color: "#1e1e2e"
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            profilePopup.visible = !profilePopup.visible
            if (profilePopup.visible) {
                getProc.output = ""
                getProc.running = true
            }
        }
    }

    // --- GET CURRENT PROFILE ---
    Process {
        id: getProc
        command: ["powerprofilesctl", "get"]
        property string output: ""
        stdout: SplitParser { onRead: data => getProc.output += data }
        onExited: {
            var profile = getProc.output.trim()
            if (profile === "performance" || profile === "balanced" || profile === "power-saver") {
                root.currentProfile = profile
                root.available = true
            } else {
                root.available = false
            }
            getProc.output = ""
        }
    }

    // --- SET PROFILE ---
    Process {
        id: setProc
        command: []
        onExited: {
            getProc.output = ""
            getProc.running = true
        }
    }

    // --- POLLING ---
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            getProc.output = ""
            getProc.running = true
        }
    }

    Component.onCompleted: {
        getProc.running = true
    }

    // --- POPUP ---
    PanelWindow {
        id: profilePopup
        visible: false
        implicitWidth: 260
        implicitHeight: 220
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors { top: true; right: true }
        margins { top: 58; right: 50 }

        Component.onCompleted: {
            if (root.QsWindow && root.QsWindow.window) {
                var globalPos = root.mapToGlobal(0, 0)
                profilePopup.margins.right = root.QsWindow.window.width - globalPos.x - root.width
            }
        }
        onVisibleChanged: {
            if (visible && root.QsWindow && root.QsWindow.window) {
                var globalPos = root.mapToGlobal(0, 0)
                profilePopup.margins.right = root.QsWindow.window.width - globalPos.x - root.width
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.background
            border.color: Theme.powerProfileColor
            border.width: 2
            radius: 12

            MouseArea { anchors.fill: parent; z: -1 }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // Header
                Text {
                    text: "󰾅  Güç Profili"
                    color: Theme.powerProfileColor
                    font.bold: true
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

                // Not available message
                Text {
                    visible: !root.available
                    text: "powerprofilesctl bulunamadı"
                    color: Theme.overlay2
                    font.pixelSize: 12
                    font.family: "JetBrainsMono Nerd Font"
                    Layout.alignment: Qt.AlignHCenter
                }

                // Profile buttons
                Repeater {
                    model: ["performance", "balanced", "power-saver"]

                    Rectangle {
                        Layout.fillWidth: true
                        height: 42
                        radius: 10
                        visible: root.available

                        property bool isActive: root.currentProfile === modelData
                        property var pData: root.profileData[modelData]

                        color: isActive ? Qt.rgba(255,255,255,0.12) : (profMa.containsMouse ? Qt.rgba(255,255,255,0.05) : "transparent")
                        border.color: isActive ? pData.color : "transparent"
                        border.width: isActive ? 2 : 0

                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: pData.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 18
                                color: isActive ? pData.color : Theme.text
                            }

                            Text {
                                text: pData.label
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.bold: isActive
                                color: isActive ? pData.color : Theme.text
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: isActive
                                text: "✓"
                                font.pixelSize: 14
                                color: pData.color
                            }
                        }

                        MouseArea {
                            id: profMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                setProc.command = ["powerprofilesctl", "set", modelData]
                                setProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }
}
