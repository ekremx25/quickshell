import QtQuick
import QtQuick.Layouts
import "../../../Widgets"

// Small rounded tile with a tinted icon, a label and a value (weather popup).
Rectangle {
    id: tile
    property string icon
    property string label
    property string value
    property color tint

    Layout.fillWidth: true
    implicitHeight: 54
    radius: 12
    color: Theme.withAlpha(Theme.raisedSurface, 0.7)
    border.width: 1
    border.color: Theme.borderFaint

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Rectangle {
            width: 32; height: 32; radius: 16
            color: Theme.withAlpha(tile.tint, 0.16)
            Text {
                anchors.centerIn: parent
                text: tile.icon
                color: tile.tint
                font.pixelSize: 15
                font.family: "JetBrainsMono Nerd Font"
                renderType: Text.NativeRendering
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
                Text { Layout.fillWidth: true; text: tile.label; color: Theme.subtext; font.pixelSize: 11; font.family: Theme.fontFamily }
            Text { Layout.fillWidth: true; text: tile.value; color: Theme.text; font.pixelSize: 14; font.bold: true; font.family: Theme.fontFamily }
        }
    }
}
