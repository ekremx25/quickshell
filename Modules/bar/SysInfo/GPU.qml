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
      text: (backend.gpuPercent >= 0 ? backend.gpuPercent + "%" : "-%") +
      (backend.gpuTemp !== "-" && backend.gpuTemp !== "0" && backend.gpuTemp !== "" ? " • " + backend.gpuTemp + "°C" : "")
      color: "#1e1e2e"
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
    accentColor: "#f5e0dc"
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
