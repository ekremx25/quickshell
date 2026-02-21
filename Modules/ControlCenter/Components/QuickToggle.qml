import QtQuick
import QtQuick.Layouts
import "../../../Widgets"

Rectangle {
    id: root
    
    // Properties
    property bool isActive: false
    property string activeIcon: "󰤨"
    property string inactiveIcon: "󰤭"
    property string activeText: "Wi-Fi"
    property string inactiveText: "Off"
    property string subtext: "" // E.g., Network name
    signal clicked()

    implicitWidth: 160
    implicitHeight: 64
    radius: height / 2

    // Theme adaptations: Active = Primary color, Inactive = Surface color
    color: isActive ? Theme.primary : Theme.surface
    Behavior on color { ColorAnimation { duration: 150 } }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        anchors.leftMargin: 16
        spacing: 12
        
        // Icon
        Text {
            text: root.isActive ? root.activeIcon : root.inactiveIcon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 22
            color: root.isActive ? Theme.base : Theme.text
        }
        
        // Texts
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            
            Text {
                text: root.isActive ? root.activeText : root.inactiveText
                font.bold: true
                font.pixelSize: 13
                color: root.isActive ? Theme.base : Theme.text
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            
            Text {
                text: root.subtext
                font.pixelSize: 11
                color: root.isActive ? Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.7) : Theme.overlay
                visible: root.subtext !== ""
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }
}
