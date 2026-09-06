import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../../Widgets"

Rectangle {
    id: clockRoot

    height: 54
    width: timeRow.implicitWidth + 40
    radius: 27
    color: Theme.panelSurface
    border.width: 1
    border.color: Theme.borderStrong

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
                color: Theme.clockColor;
                font.pixelSize: 16;
                font.family: "JetBrainsMono Nerd Font"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                font.family: Theme.fontFamily
                id: dateText
                text: ""
                color: Theme.text
                font.bold: true
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle { width: 1; height: 16; color: Theme.borderStrong; anchors.verticalCenter: parent.verticalCenter }

        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: "";
                color: Theme.primary;
                font.pixelSize: 16;
                font.family: "JetBrainsMono Nerd Font"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                font.family: Theme.fontFamily
                id: timeText
                text: ""
                color: Theme.text
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
