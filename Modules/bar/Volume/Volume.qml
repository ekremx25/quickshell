import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../Widgets"
import "../../../Services"

Rectangle {
	id: root

	// --- GÖRÜNÜM AYARLARI ---
	implicitWidth: layout.implicitWidth + 24
	implicitHeight: 34
	radius: 17

	// Ses Durumu Özellikleri (OSD ile aynı servis kaynağı)
	readonly property bool muted: Volume.sinkMuted === true
	readonly property real vol: (Volume.sinkVolume !== undefined && Volume.sinkVolume !== null) ? Volume.sinkVolume : 0

	// Sessizdeyken Kırmızı, Normalken Yeşil
	color: muted
		? (volumeMouse.containsMouse ? Qt.lighter(Theme.red, 1.15) : Theme.red)
		: (volumeMouse.containsMouse ? Qt.lighter(Theme.mediaColor, 1.15) : Theme.mediaColor)

	scale: volumeMouse.pressed ? 0.92 : (volumeMouse.containsMouse ? 1.06 : 1.0)

	// Geçiş Animasyonları
	Behavior on color { ColorAnimation { duration: 200 } }
	Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

	RowLayout {
		id: layout
		anchors.centerIn: parent
		spacing: 6

		// İKON
		Text {
			text: {
				if (root.muted || root.vol === 0) return "󰝟"
				if (root.vol >= 0.6) return "󰕾"
				if (root.vol >= 0.3) return "󰖀"
				return "󰕿"
			}
			font.pixelSize: 16
			font.family: "JetBrainsMono Nerd Font"
			color: "#1e1e2e"
		}

		// YÜZDE (Örn: 54%)
		Text {
			text: Math.round(root.vol * 100) + "%"
			font.bold: true
			font.family: "JetBrainsMono Nerd Font"
			color: "#1e1e2e"
		}
	}

	// --- KONTROLLER ---
	MouseArea {
		id: volumeMouse
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor

		// Hem Sol (Aç/Kapa) hem Orta (Mute) tuşunu dinle
		acceptedButtons: Qt.LeftButton | Qt.MiddleButton

		onClicked: (mouse) => {
			if (mouse.button === Qt.MiddleButton || mouse.button === Qt.LeftButton) {
				// SOL TIK & ORTA TIK: Sesi Tamamen Kapat (Mute)
				Volume.toggleSinkMute()
			}
		}

		// TEKERLEK: Ses Aç/Kıs
		onWheel: (wheel) => {
			var step = 0.05
			var newVol = root.vol + (wheel.angleDelta.y > 0 ? step : -step)
			// Sesi 0 ile 1.5 (%150) arasında sınırla
			Volume.setSinkVolume(Math.min(Math.max(newVol, 0.0), 1.5))
		}
	}
}
