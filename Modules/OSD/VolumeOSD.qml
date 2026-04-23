import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../Widgets"
import "../../Services"

PanelWindow {
    id: root
    
    required property var modelData
    screen: modelData

    // Position centered on both X and Y axes
    // No explicit anchors are needed as Wayland Layer Shell centers properly
    // when both implicit dimensions are defined and anchors are unset.
    anchors {
        bottom: true
    }
    margins {
        bottom: 350 // Shifted ~3cm upwards
    }
    
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    
    // Specify dimensions for compositor centering
    implicitWidth: 320
    implicitHeight: 70
    
    // Initial invisible state
    visible: false
    // State control
    property real displayVolume: (Volume.sinkVolume !== undefined && Volume.sinkVolume !== null ? Volume.sinkVolume : 0) * 100
    readonly property real clampedDisplayVolume: Math.max(0, Math.min(displayVolume, 150))
    
    // Auto-hide Timer
    Timer {
        id: hideTimer
        interval: 2500
        repeat: false
        onTriggered: {
            contentItem.opacity = 0
            hideWindowTimer.restart()
        }
    }

    Timer {
        id: hideWindowTimer
        interval: 200 // Wait slightly longer than the 150ms opacity animation
        repeat: false
        onTriggered: {
            root.visible = false
        }
    }

    function syncFromVolume() {
        const vol = (Volume.sinkVolume !== undefined && Volume.sinkVolume !== null) ? Volume.sinkVolume : 0
        root.displayVolume = Math.round(vol * 100)
    }

    Component.onCompleted: root.syncFromVolume()

    // React to Volume Changes from the Service
    Connections {
        target: Volume
        function onOsdPulse() {
            root.syncFromVolume()
            root.showOsd()
        }
        function onTargetSinkNameChanged() {
            root.syncFromVolume()
        }
        function onRefreshSerialChanged() {
            root.syncFromVolume()
            root.showOsd()
        }
    }
    
    function showOsd() {
        if (!root.visible) {
            root.visible = true
        }
        hideWindowTimer.stop()
        contentItem.opacity = 1
        hideTimer.restart()
    }

    Item {
        id: contentItem
        width: 320
        height: 70
        anchors.centerIn: parent
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // Main OSD Card UI
        Rectangle {
            anchors.fill: parent
            color: Theme.background
            border.color: Theme.surface
            border.width: 1
            radius: Theme.radius * 2
            clip: true
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                // Icon
                Text {
                    font.family: Theme.fontFamily
                    font.pixelSize: 26
                    color: Volume.sinkMuted ? Theme.red : Theme.primary
                    text: {
                        if (Volume.sinkMuted) return "󰝟"
                        if (Volume.sinkVolume > 0.6) return "󰕾"
                        if (Volume.sinkVolume > 0.3) return "󰖀"
                        if (Volume.sinkVolume > 0) return "󰕿"
                        return "󰝟"
                    }
                }
                
                // Progress Bar Container
                Rectangle {
                    Layout.fillWidth: true
                    height: 16
                    radius: 8
                    color: Qt.rgba(255,255,255, 0.05)
                    
                    // Track
                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: parent.width * (root.clampedDisplayVolume / 150)
                        radius: 8
                        color: Volume.sinkMuted ? Theme.red : Theme.primary
                        
                        // Smoothly animate visual changes in width
                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                
                // Percentage Label
                Text {
                    text: Volume.sinkMuted ? "Mute" : Math.round(root.displayVolume) + "%"
                    font.pixelSize: 15
                    font.bold: true
                    color: Volume.sinkMuted ? Theme.red : Theme.text
                    Layout.preferredWidth: 46
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Interactivity
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: {
                    if (containsMouse) {
                        hideTimer.stop()
                        contentItem.opacity = 1
                    } else {
                        hideTimer.restart()
                    }
                }
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) {
                       Volume.setSinkVolume(Volume.sinkVolume + 0.05)
                    } else {
                       Volume.setSinkVolume(Volume.sinkVolume - 0.05)
                    }
                }
            }
        }
    }
}
