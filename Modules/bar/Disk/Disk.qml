import QtQuick
import QtQuick.Layouts
import Quickshell
import "."
import "../../../Widgets"

Rectangle {
    id: diskRoot
    property bool isHovered: ma.containsMouse
    DiskService { id: diskService }

    // --- COLOR SETTINGS (Standardized) ---
    property color containerColor: Theme.diskColor
    property color iconColor: "#1e1e2e"
    property color textColor: "#1e1e2e"

    implicitHeight: 34
    implicitWidth: layout.implicitWidth + 24
    radius: 17
    color: containerColor
    border.width: 0
    // border.color: "#ccd0da"

    property alias diskUsed: diskService.diskUsed
    property alias diskTotal: diskService.diskTotal
    property alias diskPercent: diskService.diskPercent

    // --- VISUAL LAYOUT (PART VISIBLE IN THE BAR) ---
    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "󰋊" // Harddisk Icon (Nerd Font)
            color: iconColor
            font.pixelSize: 16
        }

        Text {
            text: diskService.diskPercent
            color: textColor
            font.bold: true
            font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font"
        }
    }

    // --- SAFE INTERACTION AND TOOLTIP ---
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onEntered: diskPopup.visible = true
        onExited: diskPopup.visible = false
    }

    PopupWindow {
        id: diskPopup
        visible: false

        // IMPORTANT: Making it a ghost window so it doesn't steal any clicks on the screen!
        mask: Region {}

        anchor.window: diskRoot.QsWindow.window
        anchor.onAnchoring: {
            if (!anchor.window) return;
            var isVertBar = anchor.window.height > anchor.window.width
            if (isVertBar) {
                diskPopup.anchor.rect.x = -diskPopup.width - 5
                diskPopup.anchor.rect.y = anchor.window.contentItem.mapFromItem(diskRoot, 0, 0).y + diskRoot.height/2 - diskPopup.height/2
            } else {
                diskPopup.anchor.rect.x = anchor.window.contentItem.mapFromItem(diskRoot, 0, 0).x + diskRoot.width/2 - diskPopup.width/2;
                diskPopup.anchor.rect.y = anchor.window.height + 15;
            }
        }

        implicitWidth: popupCol.implicitWidth + 30
        implicitHeight: popupCol.implicitHeight + 20
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"        // Tooltip Background: Dark Navy/Black
            border.color: "#89b4fa" // Border: Blue (so it's visible)
            border.width: 1
            radius: 12

            ColumnLayout {
                id: popupCol
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "Root Disk (/)"
                    color: "#89b4fa" // Visible Blue Title
                    font.bold: true
                    font.pixelSize: 14
                    font.family: "JetBrainsMono Nerd Font"
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#45475a" } // Separator line

                RowLayout {
                    spacing: 12
                    Text {
                        text: "󰋊" // Icon
                        color: "#cdd6f4"
                        font.pixelSize: 16
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: "Used:"
                        color: "#cdd6f4"
                        font.pixelSize: 13
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: diskService.diskUsed + " / " + diskService.diskTotal
                        color: "#a6e3a1" // Greenish
                        font.bold: true
                        font.pixelSize: 13
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }
        }
    }
}
