import QtQuick
import QtQuick.Controls as Controls
import "../../../Widgets"

Controls.AbstractButton {
    id: swatch
    required property color swatchColor
    property string label: "Color"
    property bool selected: false
    implicitWidth: 32
    implicitHeight: 32
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: label + " " + String(swatchColor).toUpperCase()
    Accessible.description: selected ? "Selected color" : "Select this color"
    contentItem: Text {
        text: swatch.selected ? "✓" : ""
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: Theme.foregroundFor(swatch.swatchColor)
        font.pixelSize: 18
        font.bold: true
    }
    background: Rectangle {
        color: swatch.swatchColor
        radius: 5
        border.width: swatch.selected || swatch.activeFocus ? 3 : 1
        border.color: swatch.selected || swatch.activeFocus ? SettingsPalette.text : Theme.withAlpha(Theme.text, 0.2)
    }
    Controls.ToolTip.visible: hovered || activeFocus
    Controls.ToolTip.text: Accessible.name + (selected ? " · Selected" : "")
}
