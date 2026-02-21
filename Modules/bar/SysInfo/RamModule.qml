import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    height: 30
    width: layout.implicitWidth + 16
    color: "#cba6f7" // Mor

    RowLayout {
        id: layout
        anchors.centerIn: parent

        Text {
            text: "28%" // Buraya ileride gerçek veri bağlanabilir
            font.bold: true
            color: "#1e1e2e"
        }
        Text {
            text: "" // RAM İkonu
            font.pixelSize: 14
            color: "#1e1e2e"
        }
    }
}
