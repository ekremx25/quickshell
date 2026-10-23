import QtQuick
import QtQuick.Layouts
import "../../../Widgets"
import "../../../Services" as S

// Effects page card with a row of style buttons bound to one string
// EffectSettings key. `options` is a list of { value, label, hint }.
Rectangle {
    id: picker
    required property string key
    required property string title
    required property string description
    required property var options

    readonly property color accent: SettingsPalette.readableAccent(Theme.primary)
    readonly property var selectedOption: {
        for (var i = 0; i < options.length; i++)
            if (options[i].value === S.EffectSettings[key]) return options[i];
        return null;
    }

    Layout.fillWidth: true
    implicitHeight: pickerCol.implicitHeight + 24
    radius: 10
    color: SettingsPalette.card
    border.color: SettingsPalette.border
    border.width: 1

    ColumnLayout {
        id: pickerCol
        anchors.fill: parent; anchors.margins: 12; spacing: 10
        EffectCardTitle { title: picker.title; description: picker.description }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: picker.options
                Rectangle {
                    id: option
                    required property var modelData
                    readonly property bool selected: S.EffectSettings[picker.key] === modelData.value
                    width: optionLabel.implicitWidth + 24; height: 30; radius: 15
                    color: selected ? picker.accent
                        : (optionMouse.containsMouse ? Qt.lighter(SettingsPalette.cardStrong, 1.15) : SettingsPalette.cardStrong)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        id: optionLabel
                        anchors.centerIn: parent
                        text: (option.selected ? "✓ " : "") + option.modelData.label
                        font.pixelSize: 12; font.family: Theme.fontFamily
                        color: option.selected ? SettingsPalette.foregroundFor(picker.accent) : SettingsPalette.text
                    }
                    MouseArea {
                        id: optionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: S.EffectSettings.set(picker.key, option.modelData.value)
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: picker.selectedOption ? picker.selectedOption.hint : ""
            font.pixelSize: 11; font.italic: true; color: SettingsPalette.subtext; font.family: Theme.fontFamily
            wrapMode: Text.WordWrap
        }
    }
}
