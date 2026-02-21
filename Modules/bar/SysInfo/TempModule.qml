import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    height: 30
    width: layout.implicitWidth + 32
    color: "#f5c2e7" // Pembe
    radius: 15

    // Sol tarafı düzleştiren yama
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
            text: "" // Senin fontunda varsa "󰏈" yapabilirsin
            font.pixelSize: 16
            color: "#1e1e2e"
        }
    }

    // --- EN SAĞLAM YÖNTEM: Donanım Dosyasını Bul ve Oku ---
    Process {
        id: tempProc
        // Bu komut şunları yapar:
        // 1. hwmon klasörlerini gezer.
        // 2. "k10temp" (senin işlemcin) ismini arar.
        // 3. Bulduğu klasördeki sıcaklık dosyasını (temp1_input) okur.
        // 4. "Sensors" komutunu çalıştırmaktan çok daha hafiftir.
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do grep -q k10temp $h/name && cat $h/temp1_input && exit; done"]
    }

    // --- VERİ OKUMA ---
    Connections {
        // Sadece süreç çalışırken bağlan (Hata vermemesi için kritik!)
        target: tempProc.running ? tempProc.stdout : null

        function onRead(data) {
            var rawVal = data.toString().trim()

            // Gelen veri sayı mı kontrol et (Örn: 46125 gelir)
            if (rawVal !== "" && !isNaN(rawVal)) {
                // 1000'e bölüp dereceye çeviriyoruz: 46125 -> 46.1
                var temp = (parseInt(rawVal) / 1000).toFixed(1)
                tempText.text = "+" + temp + "°C"
            }
        }
    }

    // --- ZAMANLAYICI (2 Saniye) ---
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: tempProc.running = true
    }
}
