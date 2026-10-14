import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"
import "../../../Services" as S

WeatherDataScope {
    id: root

    // --- PANEL FOR EACH SCREEN ---
    Variants {
        model: S.ScreenManager.getFilteredScreens("weather")

        PanelWindow {
            id: weatherPanel
            required property var modelData
            screen: modelData

            anchors { left: true; right: true; top: true; bottom: true }
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "weather-desktop"

            mask: Region { item: weatherFrame }

            readonly property string screenKey: S.ScreenManager.roleForScreenName(modelData.name)
            readonly property point savedPosition: S.DesktopWidgetPositions.position(
                "weather", screenKey, Math.max(0, width - 304), 70)

            Rectangle {
                id: weatherFrame
                x: Math.max(0, Math.min(weatherPanel.width - width, weatherPanel.savedPosition.x))
                y: Math.max(0, Math.min(weatherPanel.height - height, weatherPanel.savedPosition.y))
                width: Math.min(288, weatherPanel.width)
                height: Math.min(760, weatherPanel.height)
                color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.75)
                radius: 20
                border.color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.6)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16

                    // ═══ TITLE ═══
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            font.family: Theme.fontFamily
                            text: root.cityName
                            color: Theme.subtext
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            font.family: Theme.fontFamily
                            text: Qt.formatDateTime(new Date(), "HH:mm")
                            color: Theme.overlay2
                            font.pixelSize: 12
                        }
                    }

                    // ═══ MAIN TEMPERATURE ═══
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Text {
                            text: root.weatherIcon
                            color: Theme.yellow
                            font.pixelSize: 72
                            font.family: "JetBrainsMono Nerd Font Mono"
                            renderType: Text.NativeRendering
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 82
                            Layout.alignment: Qt.AlignHCenter
                        }
                        // Feels-like temperature (large, at the top)
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 2
                            Text {
                                text: root.popupData.feelsLike
                                color: Theme.text
                                font.pixelSize: 52
                                font.bold: true
                                font.family: Theme.fontFamily
                            }
                            Text {
                                font.family: Theme.fontFamily
                                text: "°"
                                color: Theme.primary
                                font.pixelSize: 22
                                font.bold: true
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 8
                            }
                        }
                        Text {
                            font.family: Theme.fontFamily
                            text: "Feels like"
                            color: Theme.overlay2
                            font.pixelSize: 11
                            Layout.alignment: Qt.AlignHCenter
                        }
                        // Actual temperature (small)
                        Text {
                            font.family: Theme.fontFamily
                            text: root.currentTemp + (root.useFahrenheit ? "°F" : "°C")
                            color: Theme.subtext
                            font.pixelSize: 16
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            font.family: Theme.fontFamily
                            text: root.popupData.desc
                            color: Theme.subtext
                            font.pixelSize: 14
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // ═══ SEPARATOR ═══
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.5)
                    }

                    // ═══ DETAILS ═══
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 12
                        columnSpacing: 12

                        DetailCard {
                            icon: "󰔏"
                            label: "Feels like"
                            value: root.popupData.feelsLike + "°"
                            iconColor: Theme.yellow
                        }
                        DetailCard {
                            icon: ""
                            label: "Humidity"
                            value: "%" + root.popupData.humidity
                            iconColor: Theme.primary
                        }
                        DetailCard {
                            icon: "󰖝"
                            label: "Wind"
                            value: root.popupData.wind + " km/h"
                            iconColor: Theme.green
                        }
                        DetailCard {
                            icon: ""
                            label: "Daylight"
                            value: root.popupData.sunrise + " - " + root.popupData.sunset
                            iconColor: Theme.red
                        }
                    }

                    // ═══ SEPARATOR ═══
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.5)
                    }

                    // ═══ 7 DAY FORECAST ═══
                    Text {
                        font.family: Theme.fontFamily
                        text: "5 Day Forecast"
                        color: Theme.subtext
                        font.pixelSize: 12
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: root.popupData.forecast
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 40
                                radius: 10
                                color: index === 0 ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.3)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    Text {
                                        font.family: Theme.fontFamily
                                        text: modelData.day
                                        color: index === 0 ? Theme.primary : Theme.text
                                        font.pixelSize: 12
                                        font.bold: index === 0
                                        Layout.preferredWidth: 42
                                    }
                                    Text {
                                        text: modelData.icon
                                        color: Theme.yellow
                                        font.pixelSize: 22
                                        font.family: "JetBrainsMono Nerd Font Mono"
                                        renderType: Text.NativeRendering
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        lineHeightMode: Text.FixedHeight
                                        lineHeight: 28
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 28
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        font.family: Theme.fontFamily
                                        text: modelData.min + "°"
                                        color: Theme.overlay2
                                        font.pixelSize: 12
                                    }
                                    // Mini temperature bar
                                    Rectangle {
                                        Layout.preferredWidth: 50
                                        height: 4
                                        radius: 2
                                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.6)

                                        Rectangle {
                                            width: parent.width * Math.max(0.1, Math.min(1, (modelData.max - modelData.min + 5) / 30))
                                            height: parent.height
                                            radius: 2
                                            x: parent.width * Math.max(0, Math.min(0.8, (modelData.min + 20) / 60))
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0; color: Theme.primary }
                                                GradientStop { position: 1.0; color: Theme.yellow }
                                            }
                                        }
                                    }
                                    Text {
                                        font.family: Theme.fontFamily
                                        text: modelData.max + "°"
                                        color: Theme.text
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
                MouseArea {
                    anchors.fill: parent
                    z: 20
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: weatherFrame
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: 0
                    drag.maximumX: Math.max(0, weatherPanel.width - weatherFrame.width)
                    drag.minimumY: 0
                    drag.maximumY: Math.max(0, weatherPanel.height - weatherFrame.height)
                    onReleased: S.DesktopWidgetPositions.setPosition(
                        "weather", weatherPanel.screenKey, weatherFrame.x, weatherFrame.y)
                }
            }

            // ═══ DETAIL CARD COMPONENT ═══
            component DetailCard : Rectangle {
                property string icon
                property string label
                property string value
                property color iconColor

                Layout.fillWidth: true
                height: 52
                radius: 12
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.3)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: icon
                        color: iconColor
                        font.pixelSize: 18
                        font.family: "JetBrainsMono Nerd Font"
                        renderType: Text.NativeRendering
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 22
                    }
                    ColumnLayout {
                        spacing: 1
                        Text {  text: label; color: Theme.overlay2; font.pixelSize: 10; font.family: Theme.fontFamily }
                        Text {  text: value; color: Theme.text; font.pixelSize: 13; font.bold: true; font.family: Theme.fontFamily }
                    }
                }
            }
        }
    }
}
