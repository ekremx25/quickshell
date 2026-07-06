import QtQuick
import QtQuick.Layouts
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette

Row {
    id: root

    property var options: []
    property int selectedIndex: 0
    signal selected(int idx)

    spacing: 0

    Repeater {
        model: root.options

        Rectangle {
            required property string modelData
            required property int index

            width: Math.max(segText.implicitWidth + 20, 70)
            height: 30
            radius: 6
            color: index === root.selectedIndex ? Theme.primary : Qt.rgba(49/255, 50/255, 68/255, 0.6)

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            Text {
                font.family: Theme.fontFamily
                id: segText
                anchors.centerIn: parent
                text: modelData
                color: index === root.selectedIndex ? "#1e1e2e" : SettingsPalette.text
                font.pixelSize: 11
                font.bold: index === root.selectedIndex
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selected(index)
            }
        }
    }
}
