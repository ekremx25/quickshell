import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"

PanelWindow {
    id: root

    // Make window cover the whole screen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None



    property string currentPage: "sysinfo"

    readonly property var menuItems: [
        { key: "sysinfo",    icon: "󰻀", label: "System Info" },
        { key: "monitors",   icon: "󰍹", label: "Monitors" },
        { key: "sound",      icon: "󰕾", label: "Sound" },
        { key: "network",    icon: "󰤨", label: "Network" },

    ]

    // Background click-to-close
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    // Floating Window Container
    Rectangle {
        id: mainPanel
        width: 1100
        height: 700
        color: Theme.background
        radius: Theme.radius
        border.width: 1
        border.color: Theme.surface

        // Initial Position (Top Right with margin)
        // We use x/y to allow movement within the transparent window
        x: parent.width - width - 10
        y: 50

        // Prevent click-through to background
        MouseArea {
            anchors.fill: parent
            onClicked: {} 
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ═══ SIDEBAR ═══
            Rectangle {
                Layout.preferredWidth: 200
                Layout.fillHeight: true
                color: Qt.rgba(49/255, 50/255, 68/255, 0.4)
                radius: Theme.radius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    // Başlık (Drag Area)
                    Item {
                        Layout.fillWidth: true
                        height: 30
                        
                        MouseArea {
                            id: dragMA
                            anchors.fill: parent
                            drag.target: mainPanel
                            drag.axis: Drag.XAndYAxis
                            drag.minimumX: 0
                            drag.minimumY: 0
                            drag.maximumX: root.width - mainPanel.width
                            drag.maximumY: root.height - mainPanel.height
                            cursorShape: Qt.SizeAllCursor
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            Text {
                                text: "⚙"
                                font.pixelSize: 18
                                font.family: "JetBrainsMono Nerd Font"
                                color: Theme.primary
                            }
                            Text {
                                text: "Settings"
                                color: Theme.text
                                font.pixelSize: 16
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 30; height: 30; radius: 15
                                z: 999 // Force on top
                                color: closeMA.containsMouse ? Theme.red : Qt.rgba(255,255,255,0.1)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { anchors.centerIn: parent; text: "✕"; color: Theme.text; font.pixelSize: 14; font.bold: true }
                                MouseArea {
                                    id: closeMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.visible = false;
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.06) }

                    Item { height: 6 }

                    // Menü öğeleri
                    Repeater {
                        model: root.menuItems

                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: 10
                            color: {
                                if (root.currentPage === modelData.key) return Qt.rgba(137/255, 180/255, 250/255, 0.15);
                                if (menuMA.containsMouse) return Qt.rgba(255,255,255,0.05);
                                return "transparent";
                            }

                            Behavior on color { ColorAnimation { duration: 120 } }

                            // Sol accent çizgisi
                            Rectangle {
                                visible: root.currentPage === modelData.key
                                width: 3; height: 20; radius: 2
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.primary
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: modelData.icon
                                    font.pixelSize: 16
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: root.currentPage === modelData.key ? Theme.primary : Theme.subtext
                                }

                                Text {
                                    text: modelData.label
                                    color: root.currentPage === modelData.key ? Theme.text : Theme.subtext
                                    font.pixelSize: 13
                                    font.bold: root.currentPage === modelData.key
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: menuMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentPage = modelData.key
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // Ayırıcı
            Rectangle { width: 1; Layout.fillHeight: true; color: Qt.rgba(255,255,255,0.06) }

            // ═══ İÇERİK ═══
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                SystemInfoPage {
                    anchors.fill: parent
                    visible: root.currentPage === "sysinfo"
                }

                MonitorsPage {
                    anchors.fill: parent
                    visible: root.currentPage === "monitors"
                }

                SoundPage {
                    anchors.fill: parent
                    visible: root.currentPage === "sound"
                }

                NetworkPage {
                    id: netPage
                    anchors.fill: parent
                    visible: root.currentPage === "network"
                    onRequestAddVpn: vpnPopup.open()
                }
                
                AddVpnPopup {
                    id: vpnPopup
                    onSuccess: netPage.refresh()
                }




            }
        }
    }
}
