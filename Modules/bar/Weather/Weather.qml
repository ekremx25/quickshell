import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../Widgets"

Rectangle {
    id: root

    WeatherDataScope {
        id: weatherData
    }

    property alias popupData: weatherData.popupData
    property alias currentTemp: weatherData.currentTemp
    property alias weatherIcon: weatherData.weatherIcon
    property alias cityName: weatherData.cityName
    property alias customLat: weatherData.customLat
    property alias customLon: weatherData.customLon
    property alias useFahrenheit: weatherData.useFahrenheit
    property alias weatherEnabled: weatherData.weatherEnabled

    radius: menu.visible ? 4 : 17
    implicitWidth: barRow.implicitWidth + 24
    implicitHeight: 34
    color: Theme.weatherColor

    RowLayout {
        id: barRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.weatherIcon
            color: "#1e1e2e"
            font.family: "JetBrainsMono Nerd Font Mono"
            font.pixelSize: 16
            renderType: Text.NativeRendering
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            lineHeightMode: Text.FixedHeight
            lineHeight: 19
        }

        Text {
            text: (root.currentTemp !== "-" ? root.currentTemp + (root.useFahrenheit ? "°F" : "°C") : "-")
                + (root.popupData && root.popupData.desc ? " • " + root.popupData.desc : "")
            color: "#1e1e2e"
            font.bold: true
            font.pixelSize: 13
            font.family: Theme.fontFamily
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            menu.visible = !menu.visible
            if (menu.visible) weatherData.triggerRefresh()
        }
    }

    PopupWindow {
        id: menu
        visible: false
        implicitWidth: 480
        implicitHeight: 540

        anchor {
            window: root.QsWindow.window
            onAnchoring: {
                if (!root.QsWindow || !root.QsWindow.window) return
                var win = root.QsWindow.window.contentItem
                menu.anchor.rect = win.mapFromItem(root, -(menu.width / 2 - root.width / 2), root.height + 4, root.width, root.height)
            }
        }

        MouseArea {
            anchors.fill: parent
            onPressed: mouse => {
                if (!bg.contains(Qt.point(mouse.x, mouse.y))) menu.visible = false
            }
        }

        Rectangle {
            id: bg
            anchors.fill: parent
            color: Theme.background
            border.color: Theme.surface
            border.width: 1
            radius: Theme.radius

            Text {
                text: "󰅖"
                color: Theme.text
                font.pixelSize: 22
                font.family: "JetBrainsMono Nerd Font"
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 15
                z: 10

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: menu.visible = false
                    onEntered: parent.color = Theme.red
                    onExited: parent.color = Theme.text
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    Text {
                        text: root.weatherIcon
                        color: Theme.primary
                        font.pixelSize: 64
                        font.family: "JetBrainsMono Nerd Font"
                        renderType: Text.NativeRendering
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 74
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 5
                            Text { text: root.popupData && root.popupData.feelsLike ? root.popupData.feelsLike : "-"; color: Theme.text; font.pixelSize: 36; font.bold: true }
                            Text { text: "°"; color: Theme.primary; font.pixelSize: 20; font.bold: true; Layout.alignment: Qt.AlignTop | Qt.AlignLeft; Layout.topMargin: 4 }
                        }
                        Text { text: "Feels like"; color: Theme.overlay2; font.pixelSize: 11 }
                        Text { text: root.currentTemp + (root.useFahrenheit ? "°F" : "°C"); color: Theme.subtext; font.pixelSize: 14 }
                        Text {
                            text: root.popupData && root.popupData.desc ? root.popupData.desc : ""
                            color: Theme.text
                            font.pixelSize: 16
                            font.bold: true
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        Text { text: " " + root.cityName; color: Theme.subtext; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 15
                    columnSpacing: 30

                    DetailRow { icon: ""; label: "Humidity"; value: "%" + (root.popupData && root.popupData.humidity ? root.popupData.humidity : "-"); iconColor: Theme.primary }
                    DetailRow { icon: "󰖝"; label: "Wind"; value: (root.popupData && root.popupData.wind ? root.popupData.wind : "-") + " km/h"; iconColor: Theme.primary }
                    DetailRow { icon: ""; label: "Sunrise"; value: root.popupData && root.popupData.sunrise ? root.popupData.sunrise : "-"; iconColor: "#f9e2af" }
                    DetailRow { icon: ""; label: "Sunset"; value: root.popupData && root.popupData.sunset ? root.popupData.sunset : "-"; iconColor: "#f38ba8" }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    Repeater {
                        model: root.popupData && root.popupData.forecast ? root.popupData.forecast : []
                        ColumnLayout {
                            spacing: 5
                            Layout.alignment: Qt.AlignHCenter
                            Text { text: modelData.day; color: Theme.subtext; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
                            Text {
                                text: modelData.icon
                                color: Theme.primary
                                font.pixelSize: 22
                                font.family: "JetBrainsMono Nerd Font"
                                renderType: Text.NativeRendering
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                lineHeightMode: Text.FixedHeight
                                lineHeight: 28
                                Layout.preferredHeight: 28
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text { text: modelData.min + "°/" + modelData.max + "°"; color: Theme.text; font.pixelSize: 10; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                        }
                    }
                }
            }
        }
    }

    component DetailRow : RowLayout {
        property string icon
        property string label
        property string value
        property color iconColor

        spacing: 10

        Text {
            text: icon
            color: iconColor
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
            renderType: Text.NativeRendering
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            lineHeightMode: Text.FixedHeight
            lineHeight: 20
        }
        ColumnLayout {
            spacing: 2
            Text { text: label; color: Theme.subtext; font.pixelSize: 11 }
            Text { text: value; color: Theme.text; font.pixelSize: 13; font.bold: true }
        }
    }
}
