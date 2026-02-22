import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../Widgets"

Rectangle {
    id: root
    height: 30
    width: layout.implicitWidth + 16
    color: "#cba6f7" // Mor
    radius: 15

    property bool isHovered: ma.containsMouse || tipWindow.visible

    border.width: 1
    border.color: isHovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent"

    property string ramUsageVal: "..."
    property string ramUsagePct: "0"
    property string ramTotal: "..."
    property string swapUsed: "..."
    property string swapTotal: "..."

    property var ramHistory: []
    property int ramHistMax: 40

    Process {
        id: memProc
        command: ["sh", "-c", "free -m | awk '/Mem/ {printf(\"%.0f|%.1f|%.1f\", $3/$2*100, $3/1024, $2/1024)} /Swap/ {printf(\"|%.1f|%.1f\", $3/1024, $2/1024)}'"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { memProc.buf = data.trim(); } }
        onExited: {
            if (memProc.buf !== "") {
                var parts = memProc.buf.split("|");
                if(parts.length >= 5) {
                    root.ramUsagePct = parts[0];
                    root.ramUsageVal = parts[1] + " GB";
                    root.ramTotal = parts[2] + " GB";
                    root.swapUsed = parts[3] + " GB";
                    root.swapTotal = parts[4] + " GB";

                    root.ramHistory.push(parseInt(root.ramUsagePct));
                    if (root.ramHistory.length > root.ramHistMax) {
                        root.ramHistory.shift();
                    }
                    if (tipWindow.visible) {
                         ramHistCanvas.requestPaint();
                    }
                }
            }
            memProc.buf = "";
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            memProc.running = true;
        }
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.ramUsageVal
            font.bold: true
            color: "#1e1e2e"
        }
        Text {
            text: "" // RAM İkonu
            font.pixelSize: 14
            color: "#1e1e2e"
        }
    }

    // --- TOOLTIP ---
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onEntered: tipWindow.visible = true
        onExited: tipWindow.visible = false
    }

    PopupWindow {
        id: tipWindow
        visible: false
        mask: Region {}

        anchor.window: root.QsWindow.window
        anchor.onAnchoring: {
            if (!anchor.window) return
            tipWindow.anchor.rect.x = anchor.window.contentItem.mapFromItem(root, 0, 0).x + root.width/2 - tipWindow.width/2
            tipWindow.anchor.rect.y = anchor.window.height + 5
        }

        implicitWidth: 320
        implicitHeight: col.implicitHeight + 20
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
            border.color: "#cba6f7"
            radius: 10

            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                // 1. SATIR: Kullanım ve Miktar
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Usage: " + root.ramUsagePct + "%"; color: "#cdd6f4"; font.bold: true }
                    Text { text: "|"; color: "#cba6f7"; font.bold: true }
                    Text { text: "RAM: " + root.ramUsageVal + " / " + root.ramTotal; color: "#cba6f7" }
                    Item { Layout.fillWidth: true }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#cba6f7"; opacity: 0.3; Layout.topMargin: 2; Layout.bottomMargin: 2 }

                // 2. SATIR: GRAFİK (CANVAS)
                Canvas {
                    id: ramHistCanvas
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.fillStyle = "#313244" // background
                        ctx.fillRect(0, 0, width, height)
                        ctx.fillStyle = "#cba6f7" // bar color

                        var barW = width / root.ramHistMax
                        for (var i = 0; i < root.ramHistory.length; i++) {
                            var val = root.ramHistory[i]
                            var h = (val / 100) * height
                            if (h < 1 && val > 0) h = 1
                            ctx.fillRect(i * barW, height - h, barW - 1, h)
                        }
                        
                        // Alt çizgi
                        ctx.strokeStyle = "#cba6f7"
                        ctx.beginPath(); ctx.moveTo(0, height); ctx.lineTo(width, height); ctx.stroke()
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#cba6f7"; opacity: 0.3; Layout.topMargin: 2; Layout.bottomMargin: 2 }

                // 3. SATIR: DETAYLAR (SWAP)
                Text { text: "Swap Used: " + root.swapUsed; color: "#cdd6f4"; font.family: "Monospace" }
                Text { text: "Swap Total: " + root.swapTotal; color: "#cdd6f4"; font.family: "Monospace" }
            }
        }
    }
}

