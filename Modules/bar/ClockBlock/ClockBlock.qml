import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: clockRoot

    height: 54
    width: timeRow.implicitWidth + 40
    radius: 27
    color: "#FFFFFF"
    border.width: 1
    border.color: "#E5E5EA"

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#20000000"
        shadowVerticalOffset: 4
        shadowBlur: 12
    }

    Row {
        id: timeRow
        anchors.centerIn: parent
        spacing: 15

        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: "";
                color: "#FF9500";
                font.pixelSize: 16;
                font.family: "JetBrainsMono Nerd Font"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: dateText
                text: ""
                color: "#3A3A3C"
                font.bold: true
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle { width: 1; height: 16; color: "#D1D1D6"; anchors.verticalCenter: parent.verticalCenter }

        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: "";
                color: "#007AFF";
                font.pixelSize: 16;
                font.family: "JetBrainsMono Nerd Font"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: timeText
                text: ""
                color: "#3A3A3C"
                font.bold: true
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            timeText.text = Qt.formatTime(d, "HH:mm");
            dateText.text = Qt.formatDate(d, "d MMM ddd");
        }
    }
}
