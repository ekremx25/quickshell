import QtQuick
import QtQuick.Layouts
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette

Rectangle {
    id: root

    required property string iconText
    required property color accentColor
    required property string title
    required property int volumePercent
    required property int volumeMax
    required property bool muted
    required property string mutedIconText
    required property string unmutedIconText
    required property var onToggleMute
    required property var onSetVolume

    Layout.fillWidth: true
    height: 90
    color: SettingsPalette.surface
    radius: 10

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            spacing: 8
            Text { text: root.iconText; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: root.accentColor }
            Text {
                text: root.title
                color: SettingsPalette.text
                font.bold: true
                font.pixelSize: 13
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: root.volumePercent + "%"
                color: root.accentColor
                font.bold: true
                font.pixelSize: 13
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 30
                height: 30
                radius: 8
                color: root.muted ? Qt.rgba(243/255, 139/255, 168/255, 0.2) : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.1)

                Text {
                    anchors.centerIn: parent
                    text: root.muted ? root.mutedIconText : root.unmutedIconText
                    font.pixelSize: 14
                    font.family: "JetBrainsMono Nerd Font"
                    color: root.muted ? "#f38ba8" : root.accentColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.onToggleMute) root.onToggleMute()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: Qt.rgba(49/255, 50/255, 68/255, 0.8)

                Rectangle {
                    width: parent.width * (Math.max(0, Math.min(root.volumePercent, root.volumeMax)) / root.volumeMax)
                    height: parent.height
                    radius: 3
                    color: root.accentColor

                    Behavior on width {
                        NumberAnimation { duration: 50 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    function updateVolume(mouse) {
                        if (width <= 0 || !root.onSetVolume) return;
                        root.onSetVolume((mouse.x / width) * root.volumeMax);
                    }

                    onPressed: mouse => updateVolume(mouse)
                    onPositionChanged: mouse => {
                        if (pressed) updateVolume(mouse);
                    }
                }
            }
        }
    }
}
