import QtQuick
import QtQuick.Layouts
import "../../../Widgets"

// Title + description block used by the Effects page cards.
ColumnLayout {
    id: cardTitle
    required property string title
    required property string description
    Layout.fillWidth: true
    spacing: 2

    Text { text: cardTitle.title; font.pixelSize: 14; color: SettingsPalette.text; font.family: Theme.fontFamily }
    Text {
        Layout.fillWidth: true
        text: cardTitle.description
        font.pixelSize: 11; color: SettingsPalette.subtext; font.family: Theme.fontFamily
        wrapMode: Text.WordWrap
    }
}
