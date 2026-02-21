import QtQuick
import QtQuick.Layouts
import Quickshell
import "../SysInfo"
import "../Disk"
import "../../../Widgets"

Rectangle {
    id: root
    
    // Auto-calculate width based on children
    implicitWidth: layout.implicitWidth + 24 // Margins
    implicitHeight: 34
    
    Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }

    radius: 17
    
    // Background grouping style
    color: hovered ? Qt.rgba(0, 0, 0, 0.2) : "transparent"
    Behavior on color { ColorAnimation { duration: 200 } }
    
    border.width: 1
    border.color: hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
    Behavior on border.color { ColorAnimation { duration: 200 } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        onPressed: (mouse) => mouse.accepted = false
    }

    property bool hovered: mouseArea.containsMouse || temp.isHovered || gpu.isHovered || disk.isHovered

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        // 1. Temp (Always Visible - CPU)
        Temp {
            id: temp
        }

        // 2. GPU
        GPU {
            id: gpu
            
            visible: opacity > 0
            opacity: root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            Layout.preferredWidth: root.hovered ? implicitWidth : 0
            Layout.alignment: Qt.AlignVCenter
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
            
            clip: true
        }

        // 3. Disk
        Disk {
            id: disk
            
            visible: opacity > 0
            opacity: root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            Layout.preferredWidth: root.hovered ? implicitWidth : 0
            Layout.alignment: Qt.AlignVCenter
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
            
            clip: true
        }
    }

}
