import QtQuick
import QtQuick.Layouts
import Quickshell
import "."
import "../../../Widgets"

Rectangle {
  id: root
  property bool isHovered: ma.containsMouse || tipWindow.visible
  GpuBackend { id: backend }

  implicitWidth: layout.implicitWidth + 24
  implicitHeight: 30
  radius: 15
  color: Theme.gpuColor
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
      text: "󰢮"
      color: Theme.foregroundFor(root.color)
      font.pixelSize: 16
    }

    Text {
        font.family: Theme.fontFamily
      text: (backend.gpuPercent >= 0 ? backend.gpuPercent + "%" : "-%") +
      (backend.gpuTemp !== "-" && backend.gpuTemp !== "0" && backend.gpuTemp !== "" ? " • " + backend.gpuTemp + "°C" : "")
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

  HistoryTooltip {
    id: tipWindow
    ownerItem: root
    accentColor: Theme.gpuColor
    primaryLineLeft: "Usage: " + backend.gpuPercent + "%"
    primaryLineRight: "VRAM: " + backend.vramUsed + "/" + backend.vramTotal + " GB"
    historyValues: backend.gpuHistory
    historyMax: backend.gpuHistMax
    detailLines: [
      { text: "Temp: " + backend.gpuTemp + " °C" },
      { text: "Power: " + backend.gpuPower + " W", visible: backend.gpuPower !== "-" },
      { text: "GPU Clock: " + backend.gpuClock, visible: backend.gpuClock !== "-" },
      { text: "Mem Clock: " + backend.gpuMemClock, visible: backend.gpuMemClock !== "-" },
      { text: "GPU: " + backend.gpuModel, accent: true, small: true },
      { text: "Driver: " + backend.gpuDriver }
    ]
  }
}
