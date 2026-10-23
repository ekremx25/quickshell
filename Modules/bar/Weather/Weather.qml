import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../Widgets"
import "../../../Services" as S
import "../Dock" as DockParts

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

    // In the dock (its window publishes windowScreenX) the chip is see-through so
    // the dock background shows; on the bar it keeps its coloured pill.
    readonly property bool inDock: !!root.QsWindow.window && root.QsWindow.window.windowScreenX !== undefined
    readonly property color contentColor: inDock ? Theme.text : Theme.foregroundFor(Theme.weatherColor)

    radius: menu.visible ? 4 : 17
    implicitWidth: barRow.implicitWidth + 24
    implicitHeight: 34
    color: inDock
        ? (hoverOpen.triggerHovered || menu.visible ? Theme.withAlpha(Theme.text, 0.10) : "transparent")
        : Theme.weatherColor
    Behavior on color { ColorAnimation { duration: 150 } }
    border.width: inDock ? 0 : 1
    border.color: Theme.withAlpha(root.contentColor, 0.18)

    RowLayout {
        id: barRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.weatherIcon
            color: root.inDock ? Theme.weatherColor : root.contentColor
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
            color: root.contentColor
            font.bold: true
            font.pixelSize: 13
            font.family: Theme.fontFamily
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: hoverOpen.handleClick()
    }

    HoverOpen {
        id: hoverOpen
        popup: menu
        onOpened: weatherData.triggerRefresh()
    }

    PopupWindow {
        PopupEntrance { originItem: root }  // opening animation from Settings → Effects
        id: menu
        visible: false
        color: "transparent"
        implicitWidth: 380
        implicitHeight: card.implicitHeight

        anchor {
            window: root.QsWindow.window
            onAnchoring: {
                if (!root.QsWindow || !root.QsWindow.window) return
                var host = root.QsWindow.window
                var win = host.contentItem
                // On a bottom-edge panel (the dock) open above the module instead of
                // letting the compositor flip the popup over it.
                var opensUp = host.anchors && host.anchors.bottom && !host.anchors.top
                var y = opensUp ? -menu.height - 8 : root.height + 4
                var r = win.mapFromItem(root, -(menu.width / 2 - root.width / 2), y, root.width, root.height)
                menu.anchor.rect = r
                // Remember where the popup lands on screen for the glass background.
                var hx = host.windowScreenX !== undefined ? host.windowScreenX
                    : (host.anchors && !host.anchors.left && host.anchors.right ? host.screen.width - host.width : 0)
                var hy = host.windowScreenY !== undefined ? host.windowScreenY
                    : (host.anchors && host.anchors.bottom && !host.anchors.top ? host.screen.height - host.height : 0)
                menu.glassX = hx + r.x
                menu.glassY = hy + r.y
            }
        }

        readonly property var info: root.popupData || ({})
        readonly property var forecast: info.forecast || []
        readonly property string unit: root.useFahrenheit ? "°F" : "°C"
        // Week-wide temperature span, used to place each day's range bar.
        readonly property real weekMin: forecast.reduce(function(m, d) { return Math.min(m, Number(d.min)); }, Infinity)
        readonly property real weekMax: forecast.reduce(function(m, d) { return Math.max(m, Number(d.max)); }, -Infinity)
        readonly property color accent: Theme.weatherColor
        property real glassX: 0
        property real glassY: 0

        MouseArea {
            anchors.fill: parent
            onPressed: mouse => {
                if (!card.contains(Qt.point(mouse.x, mouse.y))) menu.visible = false
            }
        }

        Rectangle {
            id: card
            width: parent.width
            implicitHeight: content.implicitHeight + 36
            radius: Theme.radius + 6
            // See-through: wallpaper glass when Liquid Glass is on, otherwise a
            // translucent panel.
            color: S.EffectSettings.liquidGlass ? "transparent" : Theme.withAlpha(Theme.panelSurface, 0.78)
            border.width: 1
            border.color: Theme.withAlpha(menu.accent, 0.35)
            clip: true

            Loader {
                anchors.fill: parent
                active: S.EffectSettings.liquidGlass && menu.visible
                sourceComponent: DockParts.LiquidGlass {
                    screen: root.QsWindow.window.screen
                    screenX: menu.glassX
                    screenY: menu.glassY
                    radius: card.radius
                    refraction: 14
                    edgeWidth: 14
                    blurRadius: 14
                    // Light frost keeps the text readable while staying see-through.
                    tint: Theme.background
                    tintStrength: 0.38
                }
            }

            // Soft glow of the weather accent behind the hero section.
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 170
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.withAlpha(menu.accent, 0.22) }
                    GradientStop { position: 1.0; color: Theme.withAlpha(menu.accent, 0.0) }
                }
            }

            // Close
            Rectangle {
                anchors { top: parent.top; right: parent.right; margins: 12 }
                width: 28; height: 28; radius: 14
                z: 10
                color: closeMouse.containsMouse ? Theme.withAlpha(Theme.red, 0.18) : Theme.withAlpha(Theme.text, 0.06)
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    color: closeMouse.containsMouse ? Theme.red : Theme.subtext
                    font.pixelSize: 14
                    font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menu.visible = false
                }
            }

            ColumnLayout {
                id: content
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                spacing: 16

                // ── Hero: place, temperature, condition ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.rightMargin: 24
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "󰍎  " + root.cityName
                            color: Theme.subtext
                            font.pixelSize: 12
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        RowLayout {
                            spacing: 2
                            Text {
                                text: root.currentTemp
                                color: Theme.text
                                font.pixelSize: 54
                                font.bold: true
                                font.family: Theme.fontFamily
                            }
                            Text {
                                text: menu.unit
                                color: menu.accent
                                font.pixelSize: 20
                                font.bold: true
                                font.family: Theme.fontFamily
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 10
                            }
                        }
                        Text {
                            text: menu.info.desc || ""
                            color: Theme.text
                            font.pixelSize: 15
                            font.bold: true
                            font.family: Theme.fontFamily
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        Text {
                            readonly property var today: menu.forecast.length > 0 ? menu.forecast[0] : null
                            text: "Feels like " + (menu.info.feelsLike || "-") + "°"
                                + (today ? "  ·  H " + today.max + "°  L " + today.min + "°" : "")
                            color: Theme.subtext
                            font.pixelSize: 12
                            font.family: Theme.fontFamily
                        }
                    }

                    Text {
                        text: root.weatherIcon
                        color: menu.accent
                        font.pixelSize: 76
                        font.family: "JetBrainsMono Nerd Font"
                        renderType: Text.NativeRendering
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                // ── Details ──
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 8

                    WeatherStatTile { icon: ""; label: "Humidity"; value: "%" + (menu.info.humidity || "-"); tint: Theme.cpSky }
                    WeatherStatTile { icon: "󰖝"; label: "Wind"; value: (menu.info.wind || "-") + " km/h"; tint: Theme.cpTeal }
                    WeatherStatTile { icon: ""; label: "Sunrise"; value: menu.info.sunrise || "-"; tint: Theme.cpYellow }
                    WeatherStatTile { icon: ""; label: "Sunset"; value: menu.info.sunset || "-"; tint: Theme.cpPeach }
                }

                // ── Forecast ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: menu.forecast.length > 0

                    Text {
                        text: "5-DAY FORECAST"
                        color: Theme.subtext
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1
                        font.family: Theme.fontFamily
                        Layout.bottomMargin: 2
                    }

                    Repeater {
                        model: menu.forecast
                        RowLayout {
                            id: dayRow
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            spacing: 10

                            Text {
                                text: dayRow.modelData.day
                                color: dayRow.index === 0 ? menu.accent : Theme.text
                                font.pixelSize: 13
                                font.bold: dayRow.index === 0
                                font.family: Theme.fontFamily
                                Layout.preferredWidth: 52
                            }
                            Text {
                                text: dayRow.modelData.icon
                                color: menu.accent
                                font.pixelSize: 18
                                font.family: "JetBrainsMono Nerd Font"
                                renderType: Text.NativeRendering
                                horizontalAlignment: Text.AlignHCenter
                                Layout.preferredWidth: 26
                            }
                            Text {
                                text: dayRow.modelData.min + "°"
                                color: Theme.subtext
                                font.pixelSize: 12
                                font.family: Theme.fontFamily
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 30
                            }
                            // Range bar: where this day's low–high sits within the week.
                            Rectangle {
                                Layout.fillWidth: true
                                height: 6
                                radius: 3
                                color: Theme.withAlpha(Theme.text, 0.08)
                                Rectangle {
                                    readonly property real span: Math.max(1, menu.weekMax - menu.weekMin)
                                    x: parent.width * (Number(dayRow.modelData.min) - menu.weekMin) / span
                                    width: Math.max(height, parent.width * (Number(dayRow.modelData.max) - Number(dayRow.modelData.min)) / span)
                                    height: parent.height
                                    radius: 3
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: Theme.cpBlue }
                                        GradientStop { position: 1.0; color: menu.accent }
                                    }
                                }
                            }
                            Text {
                                text: dayRow.modelData.max + "°"
                                color: Theme.text
                                font.pixelSize: 12
                                font.bold: true
                                font.family: Theme.fontFamily
                                Layout.preferredWidth: 30
                            }
                        }
                    }
                }
            }
        }
    }
}
