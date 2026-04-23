import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../Widgets"
import "../../../Services" as S

// Bar icon. Click toggles the popover; wheel adjusts temperature.
Rectangle {
    id: root

    implicitWidth: layout.implicitWidth + 24
    implicitHeight: 34
    radius: 17

    readonly property bool on: S.NightLight.enabled
    readonly property int temp: S.NightLight.temperature

    // Warm orange when enabled, muted surface colour when off.
    readonly property color offColor: Qt.rgba(1, 1, 1, 0.08)
    color: on
        ? (mouseArea.containsMouse ? Qt.lighter("#f9a03c", 1.15) : "#f9a03c")
        : (mouseArea.containsMouse ? Qt.lighter(offColor, 1.15) : offColor)
    Behavior on color { ColorAnimation { duration: 200 } }

    scale: mouseArea.pressed ? 0.92 : (mouseArea.containsMouse ? 1.06 : 1.0)
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.on ? "󰽥" : "󰌵"  // sun-with-filter / lightbulb-off
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
            color: root.on ? "#1e1e2e" : Theme.text
        }

        Text {
            text: root.on ? (root.temp + "K") : "Off"
            font.bold: true
            font.pixelSize: 12
            font.family: Theme.fontFamily
            color: root.on ? "#1e1e2e" : Theme.text
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                S.NightLight.setEnabled(!S.NightLight.enabled);
                return;
            }
            popover.visible = !popover.visible;
        }

        onWheel: (wheel) => {
            // Wheel up → warmer (lower K), wheel down → cooler (higher K).
            // Step size 200K keeps the slider feeling responsive without being jittery.
            var step = 200;
            var next = S.NightLight.temperature - (wheel.angleDelta.y > 0 ? step : -step);
            S.NightLight.setTemperature(next);
            if (!S.NightLight.enabled) S.NightLight.setEnabled(true);
        }
    }

    NightLightPopover {
        id: popover
    }
}
