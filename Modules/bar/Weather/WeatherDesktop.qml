import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"
import "../../../Services" as S

WeatherDataScope {
    id: root

    // --- HER EKRAN İÇİN PANEL ---
    Variants {
        model: S.ScreenManager.getFilteredScreens("weather")

        PanelWindow {
            id: weatherPanel
            required property var modelData
            screen: modelData

            anchors { right: true; top: true }
            color: "transparent"
            implicitWidth: 320
            implicitHeight: 1000
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "weather-desktop"

            // Theme { id: theme }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 16
                anchors.topMargin: 70
                anchors.bottomMargin: 40
                color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.75)
                radius: 20
                border.color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.6)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16

                    // ═══ BAŞLIK ═══
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: root.cityName
                            color: Theme.subtext
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Qt.formatDateTime(new Date(), "HH:mm")
                            color: Theme.overlay2
                            font.pixelSize: 12
                        }
                    }

                    // ═══ ANA SICAKLIK ═══
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
                        // Hissedilen sıcaklık (büyük, en başta)
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 2
                            Text {
                                text: root.popupData.feelsLike
                                color: Theme.text
                                font.pixelSize: 52
                                font.bold: true
                                font.family: "Inter"
                            }
                            Text {
                                text: "°"
                                color: Theme.primary
                                font.pixelSize: 22
                                font.bold: true
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 8
                            }
                        }
                        Text {
                            text: "Feels like"
                            color: Theme.overlay2
                            font.pixelSize: 11
                            Layout.alignment: Qt.AlignHCenter
                        }
                        // Gerçek sıcaklık (küçük)
                        Text {
                            text: root.currentTemp + (root.useFahrenheit ? "°F" : "°C")
                            color: Theme.subtext
                            font.pixelSize: 16
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: root.popupData.desc
                            color: Theme.subtext
                            font.pixelSize: 14
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // ═══ AYIRICI ═══
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.5)
                    }

                    // ═══ DETAYLAR ═══
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

                    // ═══ AYIRICI ═══
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.5)
                    }

                    // ═══ 7 GÜNLÜK TAHMİN ═══
                    Text {
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
                                        text: modelData.min + "°"
                                        color: Theme.overlay2
                                        font.pixelSize: 12
                                    }
                                    // Mini sıcaklık barı
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
            }

            // ═══ DETAY KARTI BİLEŞENİ ═══
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
                        Text { text: label; color: Theme.overlay2; font.pixelSize: 10 }
                        Text { text: value; color: Theme.text; font.pixelSize: 13; font.bold: true }
                    }
                }
            }
        }
    }
}
