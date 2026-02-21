import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../../../Widgets"

Rectangle {
    id: root

    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.5)
    radius: 12
    border.color: Qt.rgba(Theme.trayColor.r, Theme.trayColor.g, Theme.trayColor.b, 0.1)
    border.width: 1

    implicitHeight: 34
    implicitWidth: trayRow.implicitWidth + 16

    RowLayout {
        id: trayRow
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: SystemTray.items

            delegate: TrayItem {
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
