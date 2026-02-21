import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"

PopupWindow {
    id: root
    visible: false

    // Properties to configure the graph and data
    property var history: []
    property int maxHistory: 40
    property string title: ""
    property string valueText: ""
    property string subText: ""
    property color accentColor: Theme.primary
    property alias contentLayout: detailLayout.data

    // Anchor logic (same as GPU.qml)
    anchor.window: root.QsWindow.window
    anchor.onAnchoring: {
        if (!anchor.window) return
        root.anchor.rect.x = anchor.window.contentItem.mapFromItem(parentItem, 0, 0).x + parentItem.width/2 - root.width/2
        root.anchor.rect.y = anchor.window.height + 5
    }

    property Item parentItem: null // The item this tooltip is attached to

    implicitWidth: 320
    implicitHeight: mainCol.implicitHeight + 24
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(30/255, 30/255, 46/255, 0.95) // Dark background
        border.color: root.accentColor
        border.width: 1
        radius: 10

        ColumnLayout {
            id: mainCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                Text { text: root.title; color: "#cdd6f4"; font.bold: true; font.pixelSize: 14 }
                Item { Layout.fillWidth: true }
                Text { text: root.valueText; color: root.accentColor; font.bold: true; font.pixelSize: 14 }
            }

            // Subtext if any
            Text {
                visible: root.subText !== ""
                text: root.subText
                color: "#a6adc8"
                font.pixelSize: 12
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.accentColor; opacity: 0.3; Layout.topMargin: 2; Layout.bottomMargin: 2 }

            // Graph
            Canvas {
                id: graphCanvas
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    
                    // Background for graph area
                    ctx.fillStyle = Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.1)
                    ctx.fillRect(0, 0, width, height)

                    if (root.history.length === 0) return

                    ctx.fillStyle = root.accentColor
                    var barW = width / root.maxHistory
                    
                    for (var i = 0; i < root.history.length; i++) {
                        var val = root.history[i]
                        // Clamp value between 0 and 100 for drawing
                        if (val > 100) val = 100
                        if (val < 0) val = 0
                        
                        var h = (val / 100) * height
                        if (h < 1 && val > 0) h = 1
                        
                        // Draw from right to left or left to right? 
                        // GPU.qml did simple index-based drawing. Let's stick to that.
                        // Assuming new values are pushed to the end.
                        ctx.fillRect(i * barW, height - h, barW - 1, h)
                    }

                    // Bottom line
                    ctx.strokeStyle = root.accentColor
                    ctx.beginPath()
                    ctx.moveTo(0, height)
                    ctx.lineTo(width, height)
                    ctx.stroke()
                }
            }
            
            // Connect to history changes to repaint
            Connections {
                target: root
                function onHistoryChanged() { graphCanvas.requestPaint() }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.accentColor; opacity: 0.3; Layout.topMargin: 2; Layout.bottomMargin: 2 }

            // Custom Details
            ColumnLayout {
                id: detailLayout
                Layout.fillWidth: true
                spacing: 2
            }
        }
    }
}
