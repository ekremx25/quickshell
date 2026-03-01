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
    property real displayVolume: Volume.sinkVolume * 100
    
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

    // Initialize states to prevent ghost OSD popups on startup
    property int lastVolumeInt: Math.round(Volume.sinkVolume * 100)
    property bool lastMuteState: Volume.sinkMuted
    property bool isInitialized: false
    property var startupTime: Date.now()

    Component.onCompleted: {
        // Delay full initialization to allow initial Pipewire values to settle
        Qt.callLater(() => { root.isInitialized = true })
    }

    // React to Volume Changes from the Service
    Connections {
        target: Volume
        function onSinkVolumeChanged() {
            let currentVolInt = Math.round(Volume.sinkVolume * 100)
            
            // Only act if there's a real 1% change
            if (currentVolInt !== root.lastVolumeInt) {
                // If the system just started, skip the first few updates
                if (root.isInitialized && (Date.now() - root.startupTime > 1500)) {
                    // Check if this is a sudden rapid succession of events (Pipewire jitter)
                    // We only allow showing OSD if there's a distinct user-like change, but since we can't tell,
                    // we just rely on the 1% threshold and a minimum time since startup.
                    root.displayVolume = currentVolInt
                    root.lastVolumeInt = currentVolInt
                    root.refreshOSD()
                } else {
                    root.lastVolumeInt = currentVolInt
                }
            }
        }
        function onSinkMutedChanged() {
            if (Volume.sinkMuted !== root.lastMuteState) {
                // Ignore the very first initialization ghost event, but allow user events
                if (root.isInitialized) {
                    root.lastMuteState = Volume.sinkMuted
                    root.refreshOSD()
                } else {
                    root.lastMuteState = Volume.sinkMuted
                }
            }
        }
    }
    
    function refreshOSD() {
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
                    font.family: "JetBrainsMono Nerd Font"
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
                        width: parent.width * (root.displayVolume / 100)
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
