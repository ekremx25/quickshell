import QtQuick
import QtQuick.Layouts
import "SettingsPalette.js" as SettingsPalette
import "../../../Widgets"

// Provider card in the picker grid.
Rectangle {
    id: card

    required property var providerData
    required property bool selected

    signal selectRequested()

    width: 180
    height: 72
    radius: 10
    color: selected
        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
        : Qt.rgba(255, 255, 255, 0.03)
    border.color: selected
        ? Theme.primary
        : Qt.rgba(255, 255, 255, 0.08)
    border.width: selected ? 2 : 1

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: card.providerData.name
                color: SettingsPalette.text
                font.pixelSize: 13
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text {
                visible: card.selected
                text: "✓"
                color: Theme.primary
                font.pixelSize: 14
                font.bold: true
            }
        }

        Text {
            text: card.providerData.description
            color: SettingsPalette.subtext
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            elide: Text.ElideRight
            maximumLineCount: 2
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.selectRequested()
    }
}
