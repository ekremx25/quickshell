import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../../../Widgets"

Rectangle {
	id: root

	// --- GÖRÜNÜM AYARLARI ---
	implicitWidth: layout.implicitWidth + 24
	implicitHeight: 34
	radius: 17

	// Pipewire Bağlantısı
	property var audioSink: Pipewire.defaultAudioSink
	PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }

	// Ses Durumu Özellikleri (Reactivity için)
	readonly property bool muted: audioSink?.audio?.isMuted ?? false
	readonly property real vol: audioSink?.audio?.volume ?? 0

	// Sessizdeyken Kırmızı, Normalken Yeşil
	color: muted ? Theme.red : Theme.mediaColor

	// Geçiş Animasyonu
	Behavior on color { ColorAnimation { duration: 200 } }

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
		anchors.fill: parent
		cursorShape: Qt.PointingHandCursor

		// Hem Sol (Aç/Kapa) hem Orta (Mute) tuşunu dinle
		acceptedButtons: Qt.LeftButton | Qt.MiddleButton

		onClicked: (mouse) => {
			if (mouse.button === Qt.MiddleButton || mouse.button === Qt.LeftButton) {
				// SOL TIK & ORTA TIK: Sesi Tamamen Kapat (Mute)
				if (root.audioSink) root.audioSink.audio.isMuted = !root.audioSink.audio.isMuted
			}
		}

		// TEKERLEK: Ses Aç/Kıs
		onWheel: (wheel) => {
			if (root.audioSink) {
				var step = 0.05
				var newVol = root.audioSink.audio.volume + (wheel.angleDelta.y > 0 ? step : -step)
				// Sesi 0 ile 1.5 (%150) arasında sınırla
				root.audioSink.audio.volume = Math.min(Math.max(newVol, 0.0), 1.5)
			}
		}
	}
}
