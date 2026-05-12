import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../../../Widgets"

Rectangle {
    id: root

    // --- BUTTON APPEARANCE ON THE BAR ---
    implicitWidth: layout.implicitWidth + 24
    implicitHeight: 34
    radius: 17
    color: Theme.powerColor

    opacity: mouseArea.pressed ? 0.8 : 1.0
    Behavior on opacity { NumberAnimation { duration: 100 } }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "" // Power icon
            color: "#1e1e2e"
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            menuWindow.visible = true
            uptimeProc.running = true
            root.selectedIndex = 0
        }
    }

    // --- READ UPTIME ---
    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        property string uptimeText: "Uptime: Calculating..."
        stdout: SplitParser {
            onRead: (data) => {
                var text = data.trim();
                text = text.replace("up ", "Uptime: ");
                uptimeProc.uptimeText = text;
            }
        }
    }

    // --- SELECTED INDEX FOR KEYBOARD CONTROL ---
    property int selectedIndex: 0

    // --- FREE WINDOW OPENED AT THE CENTRE OF THE SCREEN ---
    Window {
        id: menuWindow
        visible: false

        // Cover the full screen (darkens the background).
        width: Screen.width
        height: Screen.height
        x: 0
        y: 0

        color: "#90000000" // Semi-transparent black

        // FIX: Qt.ToolTip blocked keyboard focus, so we removed it.
        // Qt.Popup tells Niri (Wayland) this is a menu and hands it keyboard focus.
        flags: Qt.Popup | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

        // Force focus when the window becomes visible.
        onVisibleChanged: {
            if (visible) {
                menuWindow.requestActivate()
                popupContainer.forceActiveFocus()
            }
        }

        // --- KEYBOARD SHORTCUTS (known-good approach) ---
        Shortcut { sequence: "Escape"; onActivated: menuWindow.visible = false }
        Shortcut { sequence: "Right"; onActivated: root.selectedIndex = (root.selectedIndex + 1) % 4 }
        Shortcut { sequence: "Left"; onActivated: root.selectedIndex = (root.selectedIndex + 3) % 4 }
        Shortcut { sequence: "Return"; onActivated: executeSelected() }

        // Click on the background to close.
        MouseArea {
            anchors.fill: parent
            onClicked: menuWindow.visible = false
        }

        // --- THE MENU BOX ---
        Rectangle {
            id: popupContainer
            width: 600
            height: 350
            anchors.centerIn: parent

            color: "#e61e1e2e" // Dark background (90% opacity)
            radius: 20
            border.color: "#313244"
            border.width: 1

            // Clicks inside this box must not bubble up to the background MouseArea.
            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 30

                // 1. TITLE AND UPTIME
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 5

                    Text {
                        text: "Session"
                        color: "#cdd6f4"
                        font.pixelSize: 26
                        font.bold: true
                        font.family: Theme.fontFamily
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: uptimeProc.uptimeText
                        color: "#a6adc8"
                        font.pixelSize: 14
                        font.family: Theme.fontFamily
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // 2. LARGE BUTTONS
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 15

                    Repeater {
                        model: [
                            { title: "Shutdown", icon: "", cmd: ["systemctl", "poweroff"] },
                            { title: "Reboot",   icon: "", cmd: ["systemctl", "reboot"] },
                            { title: "Suspend",  icon: "", cmd: ["systemctl", "suspend"] },
                            { title: "Log Out",  icon: "󰍃", cmd: ["niri", "msg", "action", "quit"] }
                        ]

                        Rectangle {
                            property bool isSelected: root.selectedIndex === index

                            width: 120
                            height: 120
                            radius: 24

                            // Colours: lavender when selected, dark grey otherwise.
                            color: isSelected ? "#b4befe" : "#24283b"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 15

                                Text {
                                    text: modelData.icon
                                    font.pixelSize: 36
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: isSelected ? "#1e1e2e" : "#cdd6f4"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: modelData.title
                                    font.pixelSize: 15
                                    font.bold: true
                                    font.family: Theme.fontFamily
                                    color: isSelected ? "#1e1e2e" : "#cdd6f4"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.selectedIndex = index
                                onClicked: executeSelected()
                            }
                        }
                    }
                }

                // 3. HINT FOOTER
                Text {
                    text: "Use arrow keys to navigate, Enter to select, Esc to cancel"
                    color: "#6c7086"
                    font.pixelSize: 12
                    font.family: Theme.fontFamily
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }

    // --- COMMAND EXECUTOR ---
    function executeSelected() {
        var cmds = [
            ["systemctl", "poweroff"],
            ["systemctl", "reboot"],
            ["systemctl", "suspend"],
            ["niri", "msg", "action", "quit"]
        ];

        var selectedCmd = cmds[root.selectedIndex];

        menuWindow.visible = false;
        actionProc.command = selectedCmd;
        actionProc.running = true;
    }

    Process { id: actionProc; command: []; running: false }
}
