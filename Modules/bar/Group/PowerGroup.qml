import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Battery"
import "../PowerProfile"
import "../../../Widgets"

Rectangle {
    id: root
    
    // Auto-calculate width based on children
    implicitWidth: layout.implicitWidth + 24 // Margins
    implicitHeight: 34
    
    // Smooth width animation
    Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }

    radius: 17
    
    // Background style - slightly visible when hovered to show grouping
    color: hovered ? Qt.rgba(0, 0, 0, 0.2) : "transparent"
    Behavior on color { ColorAnimation { duration: 200 } }
    
    // Border for definition
    border.width: 1
    border.color: hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
    Behavior on border.color { ColorAnimation { duration: 200 } }

    property bool hovered: mouseArea.containsMouse
    
    // Timer to delay collapse (prevent jitter when moving between icons)
    Timer {
        id: collapseTimer
        interval: 100
        onTriggered: {
            if (!mouseArea.containsMouse) root.hovered = false
        }
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        // 1. Battery (Always Visible)
        Battery {
            id: bat
        }

        // 2. PowerProfile (Expand on Hover)
        PowerProfile {
            id: profile
            
            // Interaction logic
            visible: opacity > 0
            opacity: root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
            
            // Width Logic
            Layout.preferredWidth: root.hovered ? implicitWidth : 0
            Layout.alignment: Qt.AlignVCenter
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
            
            // Clip content during animation
            clip: true
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true // Passthrough clicks
        
        onPressed: (mouse) => mouse.accepted = false // Allow children to handle clicks
    }
}
