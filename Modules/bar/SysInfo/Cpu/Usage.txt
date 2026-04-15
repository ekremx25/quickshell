import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    width: layout.implicitWidth + 16
    height: 30
    color: "#89b4fa" // Mavi
    radius: 14

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: mainText
            text: "0%"
            font.bold: true
            color: "#1e1e2e"
        }
        Text {
            text: ""
            font.pixelSize: 14
            color: "#1e1e2e"
        }
    }

    // --- VERİ MODELİ ---
    ListModel {
        id: coreModel
    }

    property var previousStats: ({})

    // --- İŞLEM (VERİ OKUMA) ---
    Process {
        id: cpuProc
        command: ["cat", "/proc/stat"]

        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("cpu")) {
                    var parts = line.split(/\s+/)
                    var name = parts[0]
                    var idle = parseFloat(parts[4]) + parseFloat(parts[5])
                    var total = 0
                    for (var i = 1; i < parts.length; i++) {
                        var val = parseFloat(parts[i])
                        if (!isNaN(val)) total += val
                    }
                    var prev = previousStats[name] || { total: 0, idle: 0 }
                    var diffTotal = total - prev.total
                    var diffIdle = idle - prev.idle
                    var usagePerc = 0
                    if (diffTotal > 0) usagePerc = (diffTotal - diffIdle) / diffTotal * 100

                        previousStats[name] = { total: total, idle: idle }
                        var finalStr = Math.round(usagePerc) + "%"

                        if (name === "cpu") {
                            mainText.text = finalStr
                        } else {
                            // İsimleri "Core0" yerine "C0" yapalım, yer kazanalım
                            var coreName = name.replace("cpu", "Core ")
                            var found = false
                            for (var k = 0; k < coreModel.count; k++) {
                                if (coreModel.get(k).name === coreName) {
                                    coreModel.setProperty(k, "usage", finalStr)
                                    found = true
                                    break
                                }
                            }
                            if (!found) coreModel.append({ name: coreName, usage: finalStr })
                        }
                }
            }
        }
    }

    // --- MOUSE & TOOLTIP (LİSTE GÖRÜNÜMÜ) ---
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        ToolTip {
            visible: parent.containsMouse
            delay: 100
            padding: 0 // Padding'i biz yöneteceğiz

            background: Rectangle {
                color: "#1e1e2e" // Koyu Arka Plan
                border.color: "#89b4fa" // Mavi Kenarlık
                radius: 8
                opacity: 0.95
            }

            // --- KESİLMEYİ ÖNLEYEN KUTU ---
            contentItem: Item {
                // İçerik ne kadarsa, etrafına 30px genişlik, 20px yükseklik payı bırak
                implicitWidth: internalCol.implicitWidth + 30
                implicitHeight: internalCol.implicitHeight + 20

                ColumnLayout {
                    id: internalCol
                    anchors.centerIn: parent
                    spacing: 8

                    // Başlık
                    Text {
                        text: "Total Load: " + mainText.text
                        font.bold: true
                        color: "#cba6f7"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // Çizgi
                    Rectangle { height: 1; width: parent.width; color: "gray"; opacity: 0.5 }

                    // LİSTE DÜZENİ (2 SÜTUN)
                    GridLayout {
                        columns: 2  // İki sütun yaptık (Uzun liste hissi verir ama sığar)
                        columnSpacing: 25 // Sütunlar arası boşluk
                        rowSpacing: 2     // Satırlar arası boşluk

                        Repeater {
                            model: coreModel
                            Row {
                                spacing: 10 // İsim ile Yüzde arasındaki boşluk
                                Text {
                                    text: model.name
                                    color: "#bac2de"
                                    font.pixelSize: 12
                                    width: 50 // Sabit genişlik (hizalama düzgün olsun diye)
                                }
                                Text {
                                    text: model.usage
                                    color: "#a6e3a1" // Yeşil Rakamlar
                                    font.bold: true
                                    font.pixelSize: 12
                                    Layout.alignment: Qt.AlignRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuProc.running = true
    }
}
