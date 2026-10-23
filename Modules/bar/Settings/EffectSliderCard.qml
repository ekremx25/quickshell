import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Widgets"
import "../../../Services" as S

// Effects page card with a slider bound to one numeric EffectSettings key.
Rectangle {
    id: card
    required property string key
    required property string title
    required property string description
    property real from: 0
    property real to: 1
    property real stepSize: 1
    property string unit: ""
    property bool available: true

    readonly property color accent: SettingsPalette.readableAccent(Theme.primary)

    Layout.fillWidth: true
    implicitHeight: sliderCol.implicitHeight + 24
    radius: 10
    color: SettingsPalette.card
    border.color: SettingsPalette.border
    border.width: 1
    opacity: available ? 1 : 0.45
    Behavior on opacity { NumberAnimation { duration: 150 } }

    ColumnLayout {
        id: sliderCol
        anchors.fill: parent; anchors.margins: 12; spacing: 8
        RowLayout {
            Layout.fillWidth: true
            EffectCardTitle { title: card.title; description: card.description }
            Text {
                text: Math.round(S.EffectSettings[card.key]) + card.unit
                font.pixelSize: 16; font.bold: true; color: card.accent; font.family: Theme.fontFamily
            }
        }
        Slider {
            id: slider
            Layout.fillWidth: true
            enabled: card.available
            from: card.from; to: card.to; stepSize: card.stepSize
            value: S.EffectSettings[card.key]
            onMoved: S.EffectSettings.set(card.key, value)
            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth; height: 6; radius: 3
                color: SettingsPalette.track
                Rectangle {
                    width: slider.visualPosition * parent.width; height: parent.height
                    radius: 3; color: card.accent
                }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 18; height: 18; radius: 9
                color: card.accent
                border.color: SettingsPalette.foregroundFor(card.accent); border.width: 2
            }
        }
    }
}
