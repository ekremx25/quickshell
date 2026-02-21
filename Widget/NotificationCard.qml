import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: cardRoot

    required property var modelData // Bildirim verisi
    required property int index
    property bool isPopup: false

    width: 350
    // İçeriğe göre uzayan yükseklik
    height: contentCol.implicitHeight + 24

    // --- TEMA RENKLERİ (Catppuccin Mocha) ---
    color: "#1e1e2e" // Arkaplan
    radius: 12
    border.width: 1
    border.color: "#313244" // Çerçeve

    // Gölge Efekti (Sadece Popup ise)
    layer.enabled: isPopup
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0,0,0,0.3)
        shadowBlur: 0.8
        shadowVerticalOffset: 4
    }

    // Tıklayınca Bildirimi Kapat
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (isPopup) {
                // Servisi çağır ve kapat
                import("../Services").Notifications.closeNotification(modelData.id);
            }
        }
    }

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // --- Başlık Satırı (İkon + İsim + Kapat) ---
        RowLayout {
            spacing: 10

            // İkon Kutusu
            Rectangle {
                width: 32; height: 32; radius: 8
                color: Qt.rgba(1,1,1,0.05)
                Image {
                    anchors.fill: parent; anchors.margins: 4
                    source: modelData.appIcon
                    visible: status === Image.Ready
                    fillMode: Image.PreserveAspectFit
                }
                // İkon yoksa harf göster
                Text {
                    anchors.centerIn: parent
                    text: "󰂚"
                    visible: parent.children[0].status !== Image.Ready
                    color: "#89b4fa"
                    font.family: "JetBrainsMono Nerd Font"
                }
            }

            // Uygulama Adı
            Text {
                text: modelData.appName
                color: "#a6adc8"
                font.bold: true
                font.pixelSize: 11
                Layout.fillWidth: true
            }

            // Çarpı Butonu
            Text {
                text: "✕"
                color: "#6c7086"
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        import("../Services").Notifications.removeNotification(index)
                    }
                }
            }
        }

        // --- Başlık Metni ---
        Text {
            text: modelData.summary
            color: "#cdd6f4"
            font.bold: true
            font.pixelSize: 13
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // --- İçerik Metni ---
        Text {
            text: modelData.body
            color: "#bac2de"
            font.pixelSize: 12
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
