import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../Widgets"

Rectangle {
	id: root

	implicitWidth: layout.implicitWidth + 24
	implicitHeight: 30
	radius: 15
	color: sysMA.containsMouse ? Qt.lighter(Theme.surface, 1.2) : Theme.surface

	Behavior on color { ColorAnimation { duration: 200 } }

	RowLayout {
		id: layout
		anchors.centerIn: parent
		spacing: 6

		Text {
			text: "⚙"
			font.pixelSize: 16
			font.family: "JetBrainsMono Nerd Font"
			color: Theme.text
		}

		Text {
			text: "Sistem"
			font.bold: true
			font.pixelSize: 12
			font.family: "JetBrainsMono Nerd Font"
			color: Theme.text
		}
	}

	SystemPanel {
		id: sysPanel
		visible: false
	}

	MouseArea {
		id: sysMA
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: sysPanel.visible = !sysPanel.visible
	}
}
