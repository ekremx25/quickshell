import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"

Rectangle {
    id: diskRoot
    property bool isHovered: ma.containsMouse

    // --- RENK AYARLARI (Standardize edilmiş) ---
    property color containerColor: Theme.diskColor
    property color iconColor: "#1e1e2e"
    property color textColor: "#1e1e2e"

    implicitHeight: 34
    implicitWidth: layout.implicitWidth + 24
    radius: 17
    color: containerColor
    border.width: 0
    // border.color: "#ccd0da"

    // --- VERİ DEĞİŞKENLERİ ---
    property string diskUsed: "0G"
    property string diskTotal: "0G"
    property string diskPercent: "0%"

    // --- DİSK BİLGİSİNİ ÇEKEN KOMUT ---
    Process {
        id: diskProc
        // df -h komutuyla root (/) diskinin boyutunu, kullanılanı ve yüzdesini alır
        command: ["sh", "-c", "df -h / | awk 'NR==2 {print $3 \"|\" $2 \"|\" $5}'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var parts = String(data).trim().split('|');
                if (parts.length >= 3) {
                    diskRoot.diskUsed = parts[0];
                    diskRoot.diskTotal = parts[1];
                    diskRoot.diskPercent = parts[2];
                }
            }
        }
    }

    // Disk güncelleme sıklığı artırıldı (5 saniye)
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            if (!diskProc.running) diskProc.running = true
        }
    }

    // --- GÖRSEL DÜZEN (BARDA GÖRÜNEN KISIM) ---
    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "󰋊" // Harddisk İkonu (Nerd Font)
            color: iconColor
            font.pixelSize: 16
        }

        Text {
            text: diskRoot.diskPercent
            color: textColor
            font.bold: true
            font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font"
        }
    }

    // --- GÜVENLİ ETKİLEŞİM VE TOOLTIP ---
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onEntered: diskPopup.visible = true
        onExited: diskPopup.visible = false
    }

    PopupWindow {
        id: diskPopup
        visible: false

        // ÖNEMLİ: Ekrandaki hiçbir tıklamayı çalmaması için hayalet pencere yapıyoruz!
        mask: Region {}

        anchor.window: diskRoot.QsWindow.window
        anchor.onAnchoring: {
            if (!anchor.window) return;
            var isVertBar = anchor.window.height > anchor.window.width
            if (isVertBar) {
                diskPopup.anchor.rect.x = -diskPopup.width - 5
                diskPopup.anchor.rect.y = anchor.window.contentItem.mapFromItem(diskRoot, 0, 0).y + diskRoot.height/2 - diskPopup.height/2
            } else {
                diskPopup.anchor.rect.x = anchor.window.contentItem.mapFromItem(diskRoot, 0, 0).x + diskRoot.width/2 - diskPopup.width/2;
                diskPopup.anchor.rect.y = anchor.window.height + 15;
            }
        }

        implicitWidth: popupCol.implicitWidth + 30
        implicitHeight: popupCol.implicitHeight + 20
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"        // Tooltip Arka Plan: Koyu Lacivert/Siyah
            border.color: "#89b4fa" // Kenarlık: Mavi (Görünür olması için)
            border.width: 1
            radius: 12

            ColumnLayout {
                id: popupCol
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "Root Disk (/)"
                    color: "#89b4fa" // Görünür Mavi Başlık
                    font.bold: true
                    font.pixelSize: 14
                    font.family: "JetBrainsMono Nerd Font"
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#45475a" } // Ayırıcı çizgi

                RowLayout {
                    spacing: 12
                    Text {
                        text: "󰋊" // Icon
                        color: "#cdd6f4"
                        font.pixelSize: 16
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: "Used:"
                        color: "#cdd6f4"
                        font.pixelSize: 13
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: diskRoot.diskUsed + " / " + diskRoot.diskTotal
                        color: "#a6e3a1" // Yeşilimsi
                        font.bold: true
                        font.pixelSize: 13
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }
        }
    }
}
