import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"

Rectangle {
  id: root
  property bool isHovered: ma.containsMouse

  // --- GÖRÜNÜM ---
  implicitWidth: layout.implicitWidth + 24
  implicitHeight: 30
  radius: 15
  color: Theme.tempColor

  RowLayout {
    id: layout
    anchors.centerIn: parent
    spacing: 6

    Text {
      text: ""
      color: "#1e1e2e"
      font.pixelSize: 16
    }

    Text {
      // "2% • 46°C"
      text: (cpuPercent >= 0 ? Math.floor(cpuPercent) + "%" : "0%") +
      (cpuTempC !== "-" ? " • " + cpuTempC + "°C" : "")
      color: "#1e1e2e"
      font.bold: true
    }
  }

  // --- DEĞİŞKENLER ---
  property real cpuPercent: 0
  property string cpuTempC: "-"
  property string loadData: "-, -, -"
  property string cpuFreqGHz: "-"
  property string governor: "-"
  property string cpuModelName: "Loading..."
  property string vCpuCount: "-"

  property var cpuHistory: []
  property int cpuHistMax: 40

  // --- 1. MODEL VE ÇEKİRDEK (Statik) ---
  Process {
    id: staticInfo
    command: ["sh", "-c",
    "model=$(grep 'model name' /proc/cpuinfo | head -n1 | cut -d: -f2 | sed 's/^ //'); " +
    "cores=$(nproc); " +
    "echo \"$model|$cores\""
    ]
    running: true
    stdout: SplitParser {
      onRead: data => {
        var parts = String(data).trim().split('|')
        if (parts.length >= 2) {
          root.cpuModelName = parts[0]
          root.vCpuCount = parts[1]
        }
      }
    }
  }

  // --- 2. CPU KULLANIMI (Hesaplama) ---
  Process {
    id: cpuCalcProc
    command: ["sh", "-c",
    "(grep '^cpu ' /proc/stat; sleep 0.5; grep '^cpu ' /proc/stat) | " +
    "awk '{t=$2+$3+$4+$5+$6+$7+$8; i=$5; if (NR==1){t1=t; i1=i;} else {dt=t-t1; di=i-i1; if(dt>0) print 100*(dt-di)/dt; else print 0;}}'"
    ]
    running: true
    stdout: SplitParser {
      onRead: data => {
        var val = parseFloat(String(data).trim())
        if (!isNaN(val)) {
          root.cpuPercent = val
          root.cpuHistory.push(val)
          if (root.cpuHistory.length > root.cpuHistMax) root.cpuHistory.shift()
            if (tipWindow.visible) cpuHistCanvas.requestPaint()
        }
      }
    }
  }

  // --- 3. DİĞER BİLGİLER (Sıcaklık Düzeltmesi Burada) ---
  Process {
    id: infoProc
    command: ["sh", "-c",
    "read -r l1 l2 l3 rest < /proc/loadavg; " +
    "freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo 0); " +
    "gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo '-'); " +

    // DÜZELTME: Önce hwmon (Ryzen/k10temp) ara, yoksa thermal_zone'a bak
    "tpath=$(grep -l 'k10temp' /sys/class/hwmon/hwmon*/name 2>/dev/null | sed 's/name/temp1_input/' | head -n1); " +
    "if [ -z \"$tpath\" ]; then tpath=$(find /sys/class/hwmon/ -name \"temp1_input\" 2>/dev/null | head -n1); fi; " +
    "if [ -z \"$tpath\" ]; then tpath=$(find /sys/class/thermal/ -name \"temp\" 2>/dev/null | head -n1); fi; " +

    "if [ -n \"$tpath\" ]; then temp=$(cat \"$tpath\" 2>/dev/null); else temp=0; fi; " +
    // Boş gelirse 0 yap
    "[ -z \"$temp\" ] && temp=0; " +

    "echo \"$l1, $l2, $l3|$freq|$gov|$temp\""
    ]
    running: true
    stdout: SplitParser {
      onRead: data => {
        var parts = String(data).trim().split('|')
        if (parts.length >= 4) {
          root.loadData = parts[0]

          var f = parseFloat(parts[1])
          root.cpuFreqGHz = (f > 0) ? (f / 1000000).toFixed(1) : "-"

          root.governor = parts[2]

          var t = parseFloat(parts[3])
          root.cpuTempC = (t > 0) ? Math.round(t / 1000) : "-"
        }
      }
    }
  }

  Timer {
    interval: 2000; running: true; repeat: true
    onTriggered: {
      cpuCalcProc.running = true
      infoProc.running = true
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
      border.color: "#fab387"
      radius: 10

      ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 4

        // 1. SATIR
        RowLayout {
          Layout.fillWidth: true
          Text { text: "Usage: " + Math.floor(root.cpuPercent) + "%"; color: "#cdd6f4"; font.bold: true }
          Text { text: "|"; color: "#fab387"; font.bold: true }
          Text { text: "Load: " + root.loadData; color: "#fab387" }
          Item { Layout.fillWidth: true }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#fab387"; opacity: 0.3; Layout.topMargin: 2; Layout.bottomMargin: 2 }

        // 2. SATIR: GRAFİK
        Canvas {
          id: cpuHistCanvas
          Layout.fillWidth: true
          Layout.preferredHeight: 50
          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "#313244"
            ctx.fillRect(0, 0, width, height)
            ctx.fillStyle = "#fab387"
            var barW = width / root.cpuHistMax
            for (var i = 0; i < root.cpuHistory.length; i++) {
              var val = root.cpuHistory[i]
              var h = (val / 100) * height
              if (h < 1) h = 1
                ctx.fillRect(i * barW, height - h, barW - 1, h)
            }
            ctx.strokeStyle = "#fab387"
            ctx.beginPath(); ctx.moveTo(0, height); ctx.lineTo(width, height); ctx.stroke()
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#fab387"; opacity: 0.3; Layout.topMargin: 2; Layout.bottomMargin: 2 }

        // 3. SATIR: DETAYLAR
        Text { text: "Temp: " + root.cpuTempC + " °C"; color: "#cdd6f4"; font.family: "Monospace" }
        Text { text: "Gov: " + root.governor; color: "#cdd6f4"; font.family: "Monospace" }
        Text { text: "CPU: " + root.cpuModelName; color: "#fab387"; font.family: "Monospace"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
        Text { text: "vCPUs: " + root.vCpuCount; color: "#cdd6f4"; font.family: "Monospace" }
        Text { text: "Freq: " + root.cpuFreqGHz + " GHz (core0)"; color: "#cdd6f4"; font.family: "Monospace" }
      }
    }
  }
}
