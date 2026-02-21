import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"

Rectangle {
  id: root
  property bool isHovered: ma.containsMouse

  implicitWidth: layout.implicitWidth + 24
  implicitHeight: 30
  radius: 15
  color: Theme.gpuColor

  RowLayout {
    id: layout
    anchors.centerIn: parent
    spacing: 6

    Text {
      text: "󰢮"
      color: "#1e1e2e"
      font.pixelSize: 16
    }

    Text {
      text: (gpuPercent >= 0 ? gpuPercent + "%" : "-%") +
      (gpuTemp !== "-" && gpuTemp !== "0" && gpuTemp !== "" ? " • " + gpuTemp + "°C" : "")
      color: "#1e1e2e"
      font.bold: true
    }
  }

  // --- DEĞİŞKENLER ---
  property int gpuPercent: 0
  property string gpuTemp: "-"
  property string vramUsed: "-"
  property string vramTotal: "-"
  property string gpuModel: "Loading..."
  property string gpuDriver: "-"
  property string gpuClock: "-"
  property string gpuMemClock: "-"
  property string gpuPower: "-"

  property var gpuHistory: []
  property int gpuHistMax: 40

  // --- GPU VERİSİ ---
  Process {
    id: gpuProc
    command: ["sh", "-c",
    "card=$(ls -d /sys/class/drm/card0/device 2>/dev/null); " +
    "if [ ! -f \"$card/mem_info_vram_used\" ]; then card=$(ls -d /sys/class/drm/card1/device 2>/dev/null); fi; " +
    "usage=$(cat \"$card/gpu_busy_percent\" 2>/dev/null || echo 0); " +
    "tempFile=$(find \"$card/hwmon\" -name \"temp1_input\" 2>/dev/null | head -n1); " +
    "if [ -n \"$tempFile\" ]; then temp=$(awk '{print int($1/1000)}' \"$tempFile\"); else temp='-'; fi; " +
    "used=$(cat \"$card/mem_info_vram_used\" 2>/dev/null || echo 0); " +
    "total=$(cat \"$card/mem_info_vram_total\" 2>/dev/null || echo 1); " +
    "usedGB=$(awk -v u=$used 'BEGIN {printf \"%.1f\", u/1073741824}'); " +
    "totalGB=$(awk -v t=$total 'BEGIN {printf \"%.1f\", t/1073741824}'); " +

    // GPU model
    "model=$(cat \"$card/../*/product_name\" 2>/dev/null || lspci | grep -i vga | sed 's/.*: //' | head -n1); " +

    // GPU clock
    "sclk=$(cat \"$card/pp_dpm_sclk\" 2>/dev/null | grep '\\*' | awk '{print $2}'); " +
    "mclk=$(cat \"$card/pp_dpm_mclk\" 2>/dev/null | grep '\\*' | awk '{print $2}'); " +
    "if [ -z \"$sclk\" ]; then sclk='-'; fi; " +
    "if [ -z \"$mclk\" ]; then mclk='-'; fi; " +

    // GPU power
    "powerFile=$(find \"$card/hwmon\" -name \"power1_average\" 2>/dev/null | head -n1); " +
    "if [ -n \"$powerFile\" ]; then power=$(awk '{printf \"%.0f\", $1/1000000}' \"$powerFile\"); else power='-'; fi; " +

    // Driver
    "drv=$(basename $(readlink \"$card/driver\") 2>/dev/null || echo '-'); " +

    "echo \"$usage|$temp|$usedGB|$totalGB|$model|$sclk|$mclk|$power|$drv\""
    ]
    running: true
    stdout: SplitParser {
      onRead: data => {
        var parts = String(data).trim().split('|')
        if (parts.length >= 4) {
          var pct = parseInt(parts[0])
          root.gpuPercent = isNaN(pct) ? 0 : pct
          root.gpuTemp = parts[1]
          root.vramUsed = parts[2]
          root.vramTotal = parts[3]
          if (parts.length >= 9) {
            root.gpuModel = parts[4] || "-"
            root.gpuClock = parts[5] || "-"
            root.gpuMemClock = parts[6] || "-"
            root.gpuPower = parts[7] || "-"
            root.gpuDriver = parts[8] || "-"
          }

          // Grafik geçmişi
          root.gpuHistory.push(root.gpuPercent)
          if (root.gpuHistory.length > root.gpuHistMax) root.gpuHistory.shift()
          if (tipWindow.visible) gpuHistCanvas.requestPaint()
        }
      }
    }
  }

  Timer { interval: 2000; running: true; repeat: true; onTriggered: gpuProc.running = true }

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
      border.color: "#f5e0dc"
      radius: 10

      ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 4

        // 1. SATIR: Kullanım ve VRAM
        RowLayout {
          Layout.fillWidth: true
          Text { text: "Usage: " + root.gpuPercent + "%"; color: "#cdd6f4"; font.bold: true }
          Text { text: "|"; color: "#f5e0dc"; font.bold: true }
          Text { text: "VRAM: " + root.vramUsed + "/" + root.vramTotal + " GB"; color: "#f5e0dc" }
          Item { Layout.fillWidth: true }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#f5e0dc"; opacity: 0.3; Layout.topMargin: 2; Layout.bottomMargin: 2 }

        // 2. SATIR: GRAFİK
        Canvas {
          id: gpuHistCanvas
          Layout.fillWidth: true
          Layout.preferredHeight: 50
          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "#313244"
            ctx.fillRect(0, 0, width, height)
            ctx.fillStyle = "#f5e0dc"
            var barW = width / root.gpuHistMax
            for (var i = 0; i < root.gpuHistory.length; i++) {
              var val = root.gpuHistory[i]
              var h = (val / 100) * height
              if (h < 1) h = 1
                ctx.fillRect(i * barW, height - h, barW - 1, h)
            }
            ctx.strokeStyle = "#f5e0dc"
            ctx.beginPath(); ctx.moveTo(0, height); ctx.lineTo(width, height); ctx.stroke()
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#f5e0dc"; opacity: 0.3; Layout.topMargin: 2; Layout.bottomMargin: 2 }

        // 3. SATIR: DETAYLAR
        Text { text: "Temp: " + root.gpuTemp + " °C"; color: "#cdd6f4"; font.family: "Monospace" }
        Text { visible: root.gpuPower !== "-"; text: "Power: " + root.gpuPower + " W"; color: "#cdd6f4"; font.family: "Monospace" }
        Text { visible: root.gpuClock !== "-"; text: "GPU Clock: " + root.gpuClock; color: "#cdd6f4"; font.family: "Monospace" }
        Text { visible: root.gpuMemClock !== "-"; text: "Mem Clock: " + root.gpuMemClock; color: "#cdd6f4"; font.family: "Monospace" }
        Text { text: "GPU: " + root.gpuModel; color: "#f5e0dc"; font.family: "Monospace"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
        Text { text: "Driver: " + root.gpuDriver; color: "#cdd6f4"; font.family: "Monospace" }
      }
    }
  }
}
