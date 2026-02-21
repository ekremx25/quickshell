import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    height: 30
    width: layout.implicitWidth + 32
    color: "#f5c2e7"
    radius: 15

    // Sol tarafı düzleştir (hap şekli)
    Rectangle {
        width: 15
        height: parent.height
        color: root.color
        anchors.left: parent.left
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: tempText
            text: "--°C"
            font.bold: true
            color: "#1e1e2e"
            font.pixelSize: 14
        }

        Text {
            text: "󰏈"  // Termometre ikonu (Nerd Font varsa)
            font.pixelSize: 16
            color: "#1e1e2e"
        }
    }

    // --- sensors komutunu direkt çalıştır ve Tctl'yi parse et ---
    Process {
        id: tempProc
        command: ["sensors"]  // Sadece "sensors" komutu yeterli

        stdout: SplitParser {
            onRead: line => {
                // Tctl satırını bul ve sıcaklığı al
                if (line.includes("Tctl:")) {
                    var parts = line.split(":")
                    if (parts.length > 1) {
                        var tempPart = parts[1].trim()
                        var temp = tempPart.split(" ")[0]  // +46.2°C kısmını al
                        tempText.text = temp  // +46.2°C göster
                    }
                }
            }
        }

        // Hata olursa konsola düşür
        stderr: SplitParser {
            onRead: line => console.log("sensors stderr: " + line)
        }
    }

    // --- HER 2 SANİYEDE YENİLE ---
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            tempProc.running = true  // Komutu yeniden çalıştır
        }
    }
}
