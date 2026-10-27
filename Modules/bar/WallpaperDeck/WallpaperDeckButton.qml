import QtQuick
import QtQuick.Layouts
import "../../../Widgets"
import "../../../Services" as S

Rectangle {
    id: root

    implicitWidth: content.implicitWidth + 22
    implicitHeight: 34
    radius: 17
    readonly property color accent: Theme.wallsColor
    readonly property color contentColor: Theme.foregroundFor(root.color)
    color: wallHover.hovered ? Qt.lighter(accent, 1.12) : accent
    scale: wallTap.pressed ? 0.92 : wallHover.hovered ? 1.06 : 1.0

    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutBack } }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "󰸉"
            color: root.contentColor
            font.family: Theme.iconFontFamily
            font.pixelSize: 17
        }

        Text {
            text: "Walls"
            color: root.contentColor
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
        }
    }

    HoverHandler {
        id: wallHover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered) S.WallpaperDeckService.open();
        }
    }

    TapHandler {
        id: wallTap
        onTapped: S.WallpaperDeckService.open()
    }
}
