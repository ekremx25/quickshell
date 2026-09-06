import QtQuick
import QtQuick.Layouts
import "../../../Widgets"

Rectangle {
    id: root
    height: 30
    width: layout.implicitWidth + 16
    color: Theme.cpBlue // Blue

    RowLayout {
        id: layout
        anchors.centerIn: parent

        Text {
            text: "2%" // Real data can be bound here later
            font.bold: true
            font.family: Theme.fontFamily
            color: Theme.foregroundFor(root.color)
        }
        Text {
            font.family: Theme.iconFontFamily
            text: "" // CPU Icon
            font.pixelSize: 14
            color: Theme.foregroundFor(root.color)
        }
    }
}
