import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import "../../../Widgets"
import "../../../Services" as S

Item {
    id: page
    readonly property var markets: S.Markets

    function currencyIndex(code) {
        for (var i = 0; i < markets.converterCurrencies.length; i++) {
            if (markets.converterCurrencies[i].code === code) return i;
        }
        return 0;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                width: 42; height: 42; radius: 13
                color: Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.13)
                Text { anchors.centerIn: parent; text: "󰄪"; color: Theme.green; font.pixelSize: 21; font.family: Theme.iconFontFamily }
            }
            ColumnLayout {
                spacing: 1
                Text { text: "Markets"; color: SettingsPalette.text; font.pixelSize: 19; font.bold: true; font.family: Theme.fontFamily }
                Text { text: "USD/TRY exchange rate and live cryptocurrency prices"; color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.fontFamily }
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
                spacing: 1
                Text { Layout.alignment: Qt.AlignRight; text: markets.updateTimeText(); color: SettingsPalette.subtext; font.pixelSize: 10; font.family: Theme.fontFamily }
                Text { Layout.alignment: Qt.AlignRight; text: markets.statusText; color: markets.refreshing ? Theme.yellow : Theme.green; font.pixelSize: 9; font.family: Theme.fontFamily }
            }
            Rectangle {
                width: 104; height: 36; radius: 10
                color: refreshMA.containsMouse ? Theme.withAlpha(Theme.primary, 0.25) : Theme.withAlpha(Theme.primary, 0.14)
                border.width: 1
                border.color: Theme.primary
                opacity: markets.refreshing ? 0.55 : 1
                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    Text { text: markets.refreshing ? "󰑐" : "󰑐"; color: Theme.primary; font.pixelSize: 13; font.family: Theme.iconFontFamily }
                    Text { text: markets.refreshing ? "Updating" : "Refresh"; color: Theme.primary; font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily }
                }
                MouseArea { id: refreshMA; anchors.fill: parent; hoverEnabled: true; enabled: !markets.refreshing; cursorShape: Qt.PointingHandCursor; onClicked: markets.refresh() }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 14
            columnSpacing: 14

            MarketCard {
                Layout.fillWidth: true
                symbol: "$"
                symbolColor: Theme.green
                title: "US Dollar"
                subtitle: "USD / TRY · TCMB"
                mainValue: "₺" + markets.formatNumber(markets.usdTrySelling, 4)
                secondaryValue: "Buying  ₺" + markets.formatNumber(markets.usdTryBuying, 4)
                detailText: markets.tcmbDate.length > 0 ? "Official rate · " + markets.tcmbDate : "Official TCMB rate"
                changeValue: 0
                showChange: false
            }

            MarketCard {
                Layout.fillWidth: true
                symbol: "₿"
                symbolColor: "#f7931a"
                title: "Bitcoin"
                subtitle: "BTC / USD"
                mainValue: "$" + markets.formatNumber(markets.bitcoinUsd, 0)
                secondaryValue: "₺" + markets.formatNumber(markets.bitcoinTry, 0)
                detailText: "24-hour market change"
                changeValue: markets.bitcoinChange
                showChange: true
            }

            MarketCard {
                Layout.fillWidth: true
                symbol: "◆"
                symbolColor: "#8c8cfa"
                title: "Ethereum"
                subtitle: "ETH / USD"
                mainValue: "$" + markets.formatNumber(markets.ethereumUsd, 2)
                secondaryValue: "₺" + markets.formatNumber(markets.ethereumTry, 0)
                detailText: "24-hour market change"
                changeValue: markets.ethereumChange
                showChange: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 176
            radius: 16
            color: Theme.withAlpha(Theme.surface, 0.42)
            border.width: 1
            border.color: Theme.withAlpha(Theme.primary, 0.18)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "󰩩"; color: Theme.primary; font.pixelSize: 18; font.family: Theme.iconFontFamily }
                    ColumnLayout {
                        spacing: 0
                        Text { text: "Currency Converter"; color: SettingsPalette.text; font.pixelSize: 13; font.bold: true; font.family: Theme.fontFamily }
                        Text { text: "Convert between currencies using the latest reference rate"; color: SettingsPalette.subtext; font.pixelSize: 9; font.family: Theme.fontFamily }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: markets.converterLoading ? "Updating…" : markets.converterStatus
                        color: markets.converterLoading ? Theme.yellow : SettingsPalette.overlay
                        font.pixelSize: 9
                        font.family: Theme.fontFamily
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        radius: 12
                        color: Theme.withAlpha(Theme.background, 0.54)
                        border.width: 1
                        border.color: amountInput.activeFocus ? Theme.primary : Theme.withAlpha(Theme.text, 0.06)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 8
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Text { text: "Amount"; color: SettingsPalette.overlay; font.pixelSize: 9; font.family: Theme.fontFamily }
                                TextInput {
                                    id: amountInput
                                    Layout.fillWidth: true
                                    text: "100"
                                    color: SettingsPalette.text
                                    font.pixelSize: 22
                                    font.bold: true
                                    font.family: Theme.fontFamily
                                    selectByMouse: true
                                    validator: DoubleValidator { bottom: 0; notation: DoubleValidator.StandardNotation }
                                }
                            }
                            CurrencyCombo {
                                id: fromCombo
                                currencies: markets.converterCurrencies
                                selectedCode: markets.converterFrom
                                onCurrencySelected: function(code) {
                                    markets.setConverterPair(code, markets.converterTo);
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 40; height: 40; radius: 12
                        color: swapMA.containsMouse ? Theme.withAlpha(Theme.primary, 0.24) : Theme.withAlpha(Theme.primary, 0.12)
                        border.width: 1; border.color: Theme.primary
                        Text { anchors.centerIn: parent; text: "󰑕"; color: Theme.primary; font.pixelSize: 17; font.family: Theme.iconFontFamily }
                        MouseArea { id: swapMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: markets.swapConverterPair() }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        radius: 12
                        color: Theme.withAlpha(Theme.background, 0.54)
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.text, 0.06)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 8
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Text { text: "Converted amount"; color: SettingsPalette.overlay; font.pixelSize: 9; font.family: Theme.fontFamily }
                                Text {
                                    Layout.fillWidth: true
                                    text: markets.currencySymbol(markets.converterTo) + " " + markets.formatConverted(markets.convertedAmount(amountInput.text))
                                    color: Theme.green
                                    font.pixelSize: 22
                                    font.bold: true
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                }
                            }
                            CurrencyCombo {
                                id: toCombo
                                currencies: markets.converterCurrencies
                                selectedCode: markets.converterTo
                                onCurrencySelected: function(code) {
                                    markets.setConverterPair(markets.converterFrom, code);
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "1 " + markets.converterFrom + " = " + markets.formatConverted(markets.converterRate) + " " + markets.converterTo
                        + (markets.converterDate.length > 0 ? "  ·  " + markets.converterDate : "")
                    color: SettingsPalette.subtext
                    font.pixelSize: 9
                    font.family: Theme.fontFamily
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 86
            radius: 14
            color: Theme.withAlpha(Theme.surface, 0.32)
            border.width: 1
            border.color: Theme.withAlpha(Theme.text, 0.05)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14
                Text { text: "󰋼"; color: Theme.primary; font.pixelSize: 20; font.family: Theme.iconFontFamily }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: "Data sources"; color: SettingsPalette.text; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                    Text {
                        Layout.fillWidth: true
                        text: "USD/TRY uses official TCMB indicative rates, BTC and ETH use CoinGecko spot prices, and currency conversion uses Frankfurter reference rates. Values are informational and are not investment advice."
                        color: SettingsPalette.subtext; font.pixelSize: 10; font.family: Theme.fontFamily; wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    component MarketCard: Rectangle {
        property string symbol: ""
        property color symbolColor: Theme.primary
        property string title: ""
        property string subtitle: ""
        property string mainValue: "--"
        property string secondaryValue: "--"
        property string detailText: ""
        property real changeValue: 0
        property bool showChange: false

        implicitHeight: 224
        radius: 18
        color: Theme.withAlpha(Theme.surface, 0.48)
        border.width: 1
        border.color: Qt.rgba(symbolColor.r, symbolColor.g, symbolColor.b, 0.25)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 9

            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    width: 42; height: 42; radius: 13
                    color: Qt.rgba(symbolColor.r, symbolColor.g, symbolColor.b, 0.14)
                    Text { anchors.centerIn: parent; text: symbol; color: symbolColor; font.pixelSize: 21; font.bold: true; font.family: Theme.fontFamily }
                }
                ColumnLayout {
                    spacing: 0
                    Text { text: title; color: SettingsPalette.text; font.pixelSize: 14; font.bold: true; font.family: Theme.fontFamily }
                    Text { text: subtitle; color: SettingsPalette.subtext; font.pixelSize: 9; font.family: Theme.fontFamily }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    visible: showChange
                    width: changeLabel.width + 18; height: 28; radius: 9
                    color: changeValue >= 0 ? Theme.withAlpha(Theme.green, 0.13) : Theme.withAlpha(Theme.red, 0.13)
                    Text {
                        id: changeLabel
                        anchors.centerIn: parent
                        text: markets.changeText(changeValue)
                        color: changeValue >= 0 ? Theme.green : Theme.red
                        font.pixelSize: 10; font.bold: true; font.family: Theme.fontFamily
                    }
                }
            }

            Item { height: 4 }
            Text { text: mainValue; color: SettingsPalette.text; font.pixelSize: 28; font.bold: true; font.family: Theme.fontFamily }
            Text { text: secondaryValue; color: symbolColor; font.pixelSize: 13; font.bold: true; font.family: Theme.fontFamily }
            Item { Layout.fillHeight: true }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.withAlpha(Theme.text, 0.06) }
            Text { text: detailText; color: SettingsPalette.overlay; font.pixelSize: 9; font.family: Theme.fontFamily }
        }
    }

    component CurrencyCombo: Basic.ComboBox {
        id: combo
        property var currencies: []
        property string selectedCode: "USD"
        signal currencySelected(string code)

        implicitWidth: 188
        implicitHeight: 42
        model: currencies
        textRole: "code"
        currentIndex: page.currencyIndex(selectedCode)
        onActivated: function(index) {
            if (currencies[index]) currencySelected(currencies[index].code);
        }

        contentItem: Text {
            leftPadding: 12
            rightPadding: 30
            text: combo.selectedCode + "  ·  " + markets.currencyName(combo.selectedCode)
            color: SettingsPalette.text
            font.pixelSize: 10
            font.bold: true
            font.family: Theme.fontFamily
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Text {
            x: combo.width - width - 10
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅀"
            color: Theme.primary
            font.pixelSize: 12
            font.family: Theme.iconFontFamily
        }

        background: Rectangle {
            radius: 9
            color: combo.hovered ? Theme.withAlpha(Theme.primary, 0.14) : Theme.withAlpha(Theme.text, 0.05)
            border.width: 1
            border.color: combo.visualFocus ? Theme.primary : Theme.withAlpha(Theme.text, 0.08)
        }

        delegate: Basic.ItemDelegate {
            width: combo.width
            height: 38
            highlighted: combo.highlightedIndex === index
            contentItem: RowLayout {
                spacing: 8
                Text { text: modelData.code; color: Theme.primary; font.pixelSize: 10; font.bold: true; font.family: Theme.fontFamily; Layout.preferredWidth: 34 }
                Text { text: modelData.name; color: SettingsPalette.text; font.pixelSize: 10; font.family: Theme.fontFamily; Layout.fillWidth: true; elide: Text.ElideRight }
                Text { text: modelData.symbol; color: SettingsPalette.overlay; font.pixelSize: 10; font.family: Theme.fontFamily }
            }
            background: Rectangle {
                color: highlighted ? Theme.withAlpha(Theme.primary, 0.16) : "transparent"
                radius: 6
            }
        }

        popup: Basic.Popup {
            y: combo.height + 4
            width: combo.width
            height: Math.min(360, contentItem.implicitHeight + 10)
            padding: 5
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex
                ScrollIndicator.vertical: Basic.ScrollIndicator { }
            }
            background: Rectangle {
                color: SettingsPalette.background
                radius: 10
                border.width: 1
                border.color: Theme.withAlpha(Theme.primary, 0.28)
            }
        }
    }
}
