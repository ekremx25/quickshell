import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"
import "../../../Services" as S

Item {
    id: root

    Variants {
        model: S.ScreenManager.getFilteredScreens("markets")

        PanelWindow {
            id: marketsWindow
            required property var modelData
            screen: modelData
            visible: S.Markets.hasData
            anchors { left: true; right: true; top: true; bottom: true }
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "markets-desktop"
            mask: Region { item: marketsFrame }

            readonly property string screenKey: S.ScreenManager.roleForScreenName(modelData.name)
            readonly property point savedPosition: S.DesktopWidgetPositions.position("markets", screenKey, 16, 240)

            Rectangle {
                id: marketsFrame
                x: Math.max(0, Math.min(marketsWindow.width - width, marketsWindow.savedPosition.x))
                y: Math.max(0, Math.min(marketsWindow.height - height, marketsWindow.savedPosition.y))
                width: Math.min(464, marketsWindow.width)
                height: 150
                radius: 20
                color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.78)
                border.width: 1
                border.color: marketsDrag.containsMouse
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
                    : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "󰄪  Markets"
                            color: Theme.text
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: S.Markets.refreshing ? "Updating…" : S.Markets.updateTimeText()
                            color: S.Markets.refreshing ? Theme.yellow : Theme.overlay2
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        MarketTile {
                            Layout.fillWidth: true
                            symbol: "$"
                            symbolColor: Theme.green
                            title: "USD / TRY"
                            value: "₺" + S.Markets.formatNumber(S.Markets.usdTrySelling, 4)
                            detail: "Buy ₺" + S.Markets.formatNumber(S.Markets.usdTryBuying, 4)
                        }

                        MarketTile {
                            Layout.fillWidth: true
                            symbol: "₿"
                            symbolColor: "#f7931a"
                            title: "BITCOIN"
                            value: "$" + S.Markets.formatNumber(S.Markets.bitcoinUsd, 0)
                            detail: S.Markets.changeText(S.Markets.bitcoinChange)
                            positive: S.Markets.bitcoinChange >= 0
                            coloredDetail: true
                        }

                        MarketTile {
                            Layout.fillWidth: true
                            symbol: "◆"
                            symbolColor: "#8c8cfa"
                            title: "ETHEREUM"
                            value: "$" + S.Markets.formatNumber(S.Markets.ethereumUsd, 2)
                            detail: S.Markets.changeText(S.Markets.ethereumChange)
                            positive: S.Markets.ethereumChange >= 0
                            coloredDetail: true
                        }
                    }
                }

                MouseArea {
                    id: marketsDrag
                    anchors.fill: parent
                    z: 20
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: marketsFrame
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: 0
                    drag.maximumX: Math.max(0, marketsWindow.width - marketsFrame.width)
                    drag.minimumY: 0
                    drag.maximumY: Math.max(0, marketsWindow.height - marketsFrame.height)
                    onReleased: S.DesktopWidgetPositions.setPosition(
                        "markets", marketsWindow.screenKey, marketsFrame.x, marketsFrame.y)
                }
            }
        }
    }

    component MarketTile: Rectangle {
        property string symbol: ""
        property color symbolColor: Theme.primary
        property string title: ""
        property string value: "--"
        property string detail: ""
        property bool coloredDetail: false
        property bool positive: true

        Layout.preferredHeight: 96
        radius: 14
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.42)
        border.width: 1
        border.color: Qt.rgba(symbolColor.r, symbolColor.g, symbolColor.b, 0.18)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: symbol
                    color: symbolColor
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }
                Text {
                    text: title
                    color: Theme.overlay2
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
            }

            Text {
                text: value
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: detail
                color: coloredDetail ? (positive ? Theme.green : Theme.red) : Theme.overlay2
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.bold: coloredDetail
            }
        }
    }
}
