import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    height: 30
    width: layout.implicitWidth + 24
    color: "#a6e3a1" // Yeşil
    radius: 15

    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

    // Köşeleri düzleştiren yama (Sağ taraf için)
    Rectangle {
        width: 15
        height: 30
        color: root.color
        anchors.right: parent.right
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: "" // Clock Icon (changed to match user screenshot potentially, or keep Gentoo if desired. User screenshot had a clock icon in image 4)
            // Original had Gentoo logo: 
            // User screenshot 4 shows a clock icon: 🕒 (or similar nerd font)
            // I will keep the existing Gentoo logo for now unless requested otherwise, OR I can switch to the clock icon if that's what "original" implies.
            // Image 1 (current?) has a Clock icon in the yellow pill.
            // Image 3 (current small green) has a Clock icon? Hard to see.
            // The code I read has `text: ""` (Gentoo Logo).
            // I will stick to the code's icon for now, or maybe the user wants the exact style of Image 4 which has a clock icon.
            // Let's stick to the code's icon to be safe, but maybe add the separator.
            font.pixelSize: 16
            color: "#1e1e2e"
        }

        Text {
            id: clockText
            text: Qt.formatTime(new Date(), "HH:mm")
            font.pixelSize: 13
            font.bold: true
            color: "#1e1e2e"
        }

        // Date part - only visible on hover
        RowLayout {
            visible: mouseArea.containsMouse
            spacing: 8
            
            Rectangle { 
                width: 1; height: 16; color: "#1e1e2e"; opacity: 0.5 
                visible: parent.visible
            }

            Text {
                text: "" // Calendar Icon
                font.pixelSize: 16
                color: "#1e1e2e"
                font.family: "JetBrainsMono Nerd Font"
            }

            Text {
                text: Qt.formatDate(new Date(), "yyyy, d MMMM dddd")
                font.pixelSize: 13
                font.bold: true
                color: "#1e1e2e"
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var d = new Date();
            clockText.text = Qt.formatTime(d, "HH:mm");
            // Force layout update if needed, but bindings should handle it
        }
    }
}
