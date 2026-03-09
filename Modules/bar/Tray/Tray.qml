import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../../../Widgets"

Rectangle {
    id: root

    color: "transparent"
    radius: 17
    border.color: Qt.rgba(1, 1, 1, 0.12)
    border.width: 1

    implicitHeight: 34
    implicitWidth: trayRow.implicitWidth + 18

    RowLayout {
        id: trayRow
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: SystemTray.items

            delegate: TrayItem {
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
