import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../Widgets"
import "../../Services"
import "../bar/Dock" as DockParts

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

        // Frosted glass card. The window ignores exclusive zones and is anchored
        // bottom-centre, so its screen position follows from size and margin.
        Loader {
            anchors.fill: parent
            active: EffectSettings.liquidGlass && root.visible
            sourceComponent: DockParts.LiquidGlass {
                screen: root.screen
                screenX: (root.screen.width - root.width) / 2 + contentItem.x
                screenY: root.screen.height - 350 - root.height + contentItem.y
                radius: Theme.radius * 2
                refraction: 14
                edgeWidth: 14
                blurRadius: 14
                tint: Theme.background
                tintStrength: 0.4
            }
        }

        // Main OSD Card UI
        Rectangle {
            anchors.fill: parent
            color: EffectSettings.liquidGlass ? "transparent" : Theme.background
            border.color: Theme.surface
            border.width: EffectSettings.liquidGlass ? 0 : 1
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
                    height: 18
                    radius: 9
                    color: Theme.withAlpha(Theme.text, 0.07)

                    // Liquid fill: the leading edge ripples like water while the OSD is shown.
                    Canvas {
                        id: liquidFill
                        anchors.fill: parent
                        property real level: root.clampedDisplayVolume / 150
                        property real phase: 0
                        property color fillColor: Volume.sinkMuted ? Theme.red : Theme.primary
                        Behavior on level { SpringAnimation { spring: 4.5; damping: 0.32; epsilon: 0.001 } }
                        Behavior on fillColor { ColorAnimation { duration: 150 } }
                        onLevelChanged: requestPaint()
                        onPhaseChanged: requestPaint()
                        onFillColorChanged: requestPaint()

                        NumberAnimation on phase {
                            from: 0; to: Math.PI * 2; duration: EffectSettings.ms(1400)
                            loops: Animation.Infinite
                            running: root.visible && EffectSettings.osdWave
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            var w = width, h = height, r = h / 2;
                            ctx.reset();
                            ctx.save();
                            ctx.beginPath();
                            ctx.roundedRect(0, 0, w, h, r, r);
                            ctx.clip();

                            var edge = Math.max(0, Math.min(1, level)) * w;
                            if (edge > 0.5) {
                                var amp = EffectSettings.osdWave && edge < w - 1 ? 3 : 0;
                                ctx.beginPath();
                                ctx.moveTo(0, 0);
                                for (var y = 0; y <= h; y += 1) {
                                    var t = y / h * Math.PI * 2;
                                    ctx.lineTo(edge + amp * Math.sin(t + phase) + amp * 0.5 * Math.sin(2 * t - phase * 1.5), y);
                                }
                                ctx.lineTo(0, h);
                                ctx.closePath();
                                ctx.fillStyle = fillColor;
                                ctx.fill();

                                // Glossy highlight on the upper half of the liquid.
                                var gloss = ctx.createLinearGradient(0, 0, 0, h);
                                gloss.addColorStop(0, Qt.rgba(1, 1, 1, 0.35));
                                gloss.addColorStop(0.5, Qt.rgba(1, 1, 1, 0.05));
                                gloss.addColorStop(1, Qt.rgba(1, 1, 1, 0));
                                ctx.fillStyle = gloss;
                                ctx.fill();
                            }
                            ctx.restore();
                        }
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
