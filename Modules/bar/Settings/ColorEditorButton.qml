import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../../Widgets"

Controls.Button {
    id: action
    property bool prominent: false
    readonly property color accentColor: SettingsPalette.readableAccent(Theme.primary)
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: 38
    implicitWidth: actionLabel.implicitWidth + 24
    contentItem: Text {
        id: actionLabel
        text: action.text
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.bold: action.prominent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: action.prominent ? Theme.foregroundFor(action.accentColor) : SettingsPalette.text
    }
    background: Rectangle {
        radius: 8
        color: action.prominent ? action.accentColor : SettingsPalette.withAlpha(SettingsPalette.text, action.down ? 0.16 : action.hovered ? 0.10 : 0.04)
        border.width: action.activeFocus ? 2 : 1
        border.color: action.activeFocus ? SettingsPalette.text : SettingsPalette.border
        Behavior on color { ColorAnimation { duration: 140 } }
    }
    opacity: enabled ? 1 : 0.4
}
