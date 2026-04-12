import QtQuick
import QtQuick.Layouts
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette

Rectangle {
    id: root

    required property string title
    required property string description
    required property bool checked
    required property var onToggle

    Layout.fillWidth: true
    height: 70
    color: SettingsPalette.surface
    radius: 12

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: root.title; color: SettingsPalette.text; font.bold: true; font.pixelSize: 14 }
            Text { text: root.description; color: SettingsPalette.subtext; font.pixelSize: 11 }
        }

        Rectangle {
            width: 48
            height: 26
            radius: 13
            color: root.checked ? Theme.primary : Qt.rgba(49/255, 50/255, 68/255, 0.8)

            Behavior on color { ColorAnimation { duration: 200 } }

            Rectangle {
                width: 20
                height: 20
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                x: root.checked ? parent.width - width - 3 : 3
                color: "white"

                Behavior on x {
                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.onToggle) root.onToggle()
            }
        }
    }
}
