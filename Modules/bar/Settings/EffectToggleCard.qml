import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Widgets"
import "../../../Services" as S

// Effects page card with a switch bound to one boolean EffectSettings key.
Rectangle {
    id: toggle
    required property string key
    required property string title
    required property string description
    property bool available: true

    readonly property color accent: SettingsPalette.readableAccent(Theme.primary)

    Layout.fillWidth: true
    implicitHeight: toggleRow.implicitHeight + 24
    radius: 10
    color: SettingsPalette.card
    border.color: SettingsPalette.border
    border.width: 1
    opacity: available ? 1 : 0.45
    Behavior on opacity { NumberAnimation { duration: 150 } }

    RowLayout {
        id: toggleRow
        anchors.fill: parent; anchors.margins: 12; spacing: 16
        EffectCardTitle { title: toggle.title; description: toggle.description }
        Switch {
            enabled: toggle.available
            checked: S.EffectSettings[toggle.key] === true
            onToggled: S.EffectSettings.set(toggle.key, checked)
            indicator: Rectangle {
                implicitWidth: 40; implicitHeight: 20; radius: 10
                color: parent.checked ? toggle.accent : SettingsPalette.cardStrong
                border.color: Theme.withAlpha(Theme.text, 0.1)
                Rectangle {
                    x: parent.parent.checked ? parent.width - width - 2 : 2
                    width: 16; height: 16; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: parent.parent.checked ? SettingsPalette.foregroundFor(toggle.accent) : SettingsPalette.text
                    Behavior on x { NumberAnimation { duration: 100 } }
                }
            }
        }
    }
}
