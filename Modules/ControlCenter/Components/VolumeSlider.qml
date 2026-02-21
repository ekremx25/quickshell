import QtQuick
import QtQuick.Layouts
import "../../../Widgets"
import "../../../Services"

Item {
    id: root

    implicitWidth: 340
    implicitHeight: 50 // Gnome sliders are somewhat tall but distinct

    RowLayout {
        anchors.fill: parent
        spacing: 16
        
        // Thick Slider Track
        Rectangle {
            Layout.fillWidth: true
            height: 48
            radius: 24
            color: Theme.surface // Background of slider
            
            // Filled portion
            Rectangle {
                width: Math.max(height, parent.width * Volume.sinkVolume)
                height: parent.height
                radius: parent.radius
                color: Volume.sinkMuted ? Theme.red : Theme.primary
                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
            
            // Icon placed inside/on-top-of the slider at the left
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (Volume.sinkMuted) return "󰝟"
                    if (Volume.sinkVolume > 0.6) return "󰕾"
                    if (Volume.sinkVolume > 0.3) return "󰖀"
                    if (Volume.sinkVolume > 0) return "󰕿"
                    return "󰝟"
                }
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 20
                // If it's on the filled part, it should be base color. If volume is 0, it might be on the surface part.
                color: Volume.sinkVolume > 0.1 || Volume.sinkVolume === 1 ? Theme.base : Theme.text
                
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Volume.toggleSinkMute()
                }
            }
            
            MouseArea {
                anchors.fill: parent
                // Don't intercept clicks on the icon itself if possible, but fine here
                function setVol(mouse) {
                    var v = Math.min(Math.max(mouse.x / width, 0), 1);
                    Volume.setSinkVolume(v);
                }
                onPressed: (mouse) => setVol(mouse)
                onPositionChanged: (mouse) => setVol(mouse)
            }
        }
    }
}
