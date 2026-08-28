import QtQuick
import QtQuick.Layouts
import Quickshell
import "."
import "../../../Widgets"

Rectangle {
  id: root
  property bool isHovered: ma.containsMouse
  TempBackend { id: backend }

  // --- APPEARANCE ---
  implicitWidth: layout.implicitWidth + 24
  implicitHeight: 30
  radius: 15
  color: Theme.cpuColor
  Behavior on color { ColorAnimation { duration: Theme.animMedium } }
  border.width: 1
  border.color: Qt.rgba(
    Theme.foregroundFor(root.color).r,
    Theme.foregroundFor(root.color).g,
    Theme.foregroundFor(root.color).b,
    0.18)

  RowLayout {
    id: layout
    anchors.centerIn: parent
    spacing: 6

    Text {
        font.family: Theme.iconFontFamily
      text: ""
      color: Theme.foregroundFor(root.color)
      font.pixelSize: 16
    }

    Text {
        font.family: Theme.fontFamily
      // "2% • 46°C"
      text: (backend.cpuPercent >= 0 ? Math.floor(backend.cpuPercent) + "%" : "0%") +
      (backend.cpuTempC !== "-" ? " • " + backend.cpuTempC + "°C" : "")
      color: Theme.foregroundFor(root.color)
      font.bold: true
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
        var isVertBar = anchor.window.height > anchor.window.width
        if (isVertBar) {
            tipWindow.anchor.rect.x = -tipWindow.width - 5
            tipWindow.anchor.rect.y = anchor.window.contentItem.mapFromItem(root, 0, 0).y + root.height/2 - tipWindow.height/2
        } else {
            tipWindow.anchor.rect.x = anchor.window.contentItem.mapFromItem(root, 0, 0).x + root.width/2 - tipWindow.width/2
            tipWindow.anchor.rect.y = anchor.window.height + 5
        }
    }

    implicitWidth: 320
    implicitHeight: col.implicitHeight + 20
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      color: Theme.background
      border.color: Theme.cpuColor
      radius: 10

      ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 4

        // ROW 1
        RowLayout {
          Layout.fillWidth: true
          Text {  text: "Usage: " + Math.floor(backend.cpuPercent) + "%"; color: Theme.text; font.bold: true; font.family: Theme.fontFamily }
          Text {  text: "|"; color: Theme.cpuColor; font.bold: true; font.family: Theme.fontFamily }
          Text {  text: "Load: " + backend.loadData; color: Theme.cpuColor; font.family: Theme.fontFamily }
          Item { Layout.fillWidth: true }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.cpuColor; opacity: 0.3; Layout.topMargin: 2; Layout.bottomMargin: 2 }

        // ROW 2: GRAPH
        Canvas {
          id: cpuHistCanvas
          Layout.fillWidth: true
          Layout.preferredHeight: 50
          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = Theme.surface.toString()
            ctx.fillRect(0, 0, width, height)
            ctx.fillStyle = Theme.cpuColor.toString()
            var barW = width / backend.cpuHistMax
            for (var i = 0; i < backend.cpuHistory.length; i++) {
              var val = backend.cpuHistory[i]
              var h = (val / 100) * height
              if (h < 1) h = 1
                ctx.fillRect(i * barW, height - h, barW - 1, h)
            }
            ctx.strokeStyle = Theme.cpuColor.toString()
            ctx.beginPath(); ctx.moveTo(0, height); ctx.lineTo(width, height); ctx.stroke()
          }

          Connections {
            target: Theme
            function onCpuColorChanged() { cpuHistCanvas.requestPaint() }
            function onSurfaceChanged() { cpuHistCanvas.requestPaint() }
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.cpuColor; opacity: 0.3; Layout.topMargin: 2; Layout.bottomMargin: 2 }

        // ROW 3: DETAILS
        Text { text: "Temp: " + backend.cpuTempC + " °C"; color: Theme.text; font.family: Theme.monoFontFamily }
        Text { text: "Gov: " + backend.governor; color: Theme.text; font.family: Theme.monoFontFamily }
        Text { text: "CPU: " + backend.cpuModelName; color: Theme.cpuColor; font.family: Theme.monoFontFamily; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
        Text { text: "vCPUs: " + backend.vCpuCount; color: Theme.text; font.family: Theme.monoFontFamily }
        Text { text: "Freq: " + backend.cpuFreqGHz + " GHz (core0)"; color: Theme.text; font.family: Theme.monoFontFamily }
      }
    }
  }
}
