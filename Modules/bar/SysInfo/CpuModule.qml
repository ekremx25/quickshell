import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    height: 30
    width: layout.implicitWidth + 16
    color: "#89b4fa" // Mavi

    RowLayout {
        id: layout
        anchors.centerIn: parent

        Text {
            text: "2%" // Buraya ileride gerçek veri bağlanabilir
            font.bold: true
            color: "#1e1e2e"
        }
        Text {
            text: "" // CPU İkonu
            font.pixelSize: 14
            color: "#1e1e2e"
        }
    }
}
