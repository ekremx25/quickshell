import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../Widgets"

Rectangle {
	id: root

	implicitWidth: layout.implicitWidth + 24
	implicitHeight: 30
	radius: 15
	color: Theme.displayColor

	Behavior on color { ColorAnimation { duration: 200 } }

	RowLayout {
		id: layout
		anchors.centerIn: parent
		spacing: 6

		Text {
			text: "󰍹"
			font.pixelSize: 18
			font.family: "JetBrainsMono Nerd Font"
			color: Theme.base
		}

		Text {
			text: "Ekran"
			font.bold: true
			font.family: "JetBrainsMono Nerd Font"
			color: Theme.base
		}
	}

	DisplayPopup {
		id: displayMenu
		visible: false
	}

	MouseArea {
		anchors.fill: parent
		cursorShape: Qt.PointingHandCursor
		onClicked: displayMenu.visible = !displayMenu.visible
	}
}
