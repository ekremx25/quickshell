import QtQuick
import QtQuick.Layouts
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette

Rectangle {
    id: root

    required property string iconText
    required property color accentColor
    required property string title
    required property var rows
    property string badgeText: ""
    property color badgeColor: accentColor
    property bool useSurfaceColor: false
    property real preferredLabelWidth: 80
    default property alias content: contentCol.data

    Layout.fillWidth: true
    implicitHeight: contentCol.implicitHeight + 24
    color: useSurfaceColor ? SettingsPalette.surface : Qt.rgba(49/255, 50/255, 68/255, 0.4)
    radius: 12

    ColumnLayout {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        RowLayout {
            spacing: 8
            Text { text: root.iconText; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: root.accentColor }
            Text { text: root.title; color: SettingsPalette.text; font.bold: true; font.pixelSize: 14 }
            Item { Layout.fillWidth: true }
            Text {
                visible: root.badgeText !== ""
                text: root.badgeText
                color: root.badgeColor
                font.bold: true
                font.pixelSize: 13
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.04) }

        Repeater {
            model: root.rows || []

            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: modelData.label + ":"
                    color: SettingsPalette.subtext
                    font.pixelSize: 12
                    Layout.preferredWidth: root.preferredLabelWidth
                }

                Text {
                    text: modelData.value || "..."
                    color: SettingsPalette.text
                    font.pixelSize: 12
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }
    }
}
