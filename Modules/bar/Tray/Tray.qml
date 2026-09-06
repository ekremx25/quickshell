import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../../../Widgets"

Rectangle {
    id: root

    color: "transparent"
    radius: 17
    border.color: Theme.withAlpha(Theme.text, 0.12)
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
