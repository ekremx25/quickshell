import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Basic
import Quickshell
import Quickshell.Wayland
import "../../Widgets"
import "../../Services" as S

Rectangle {
    id: root

    // Every converter surface is derived from the active Theme singleton, so
    // Material You, light/dark mode and preset changes apply live.
    // Currency has its own semantic theme role. Static monochrome is handled
    // explicitly because it intentionally has no chromatic accents.
    readonly property bool monochromeMode: (S.ColorPaletteService.enabled
        && S.ColorPaletteService.matugenType === "scheme-monochrome")
        || Theme.currentThemeName === "Monochrome"
    readonly property color chipColor: monochromeMode ? Theme.ramColor : Theme.currencyColor
    readonly property color accentColor: monochromeMode ? Theme.text : Theme.currencyColor
    readonly property color chipTextColor: Theme.foregroundFor(chipColor)
    readonly property color mutedColor: Theme.subtext
    // Preserve the selected theme's RGB values, but keep the converter fully
    // opaque so windows underneath never bleed through.
    readonly property color panelColor: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 1.0)
    readonly property color cardColor: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 1.0)
    readonly property color softBorder: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10)

    implicitWidth: compactRow.implicitWidth + 20
    implicitHeight: 34
    radius: 17
    color: converterMouse.containsMouse || converterPopup.visible
        ? Qt.lighter(chipColor, 1.08)
        : chipColor
    border.width: 1
    border.color: converterPopup.visible
        ? Qt.rgba(chipTextColor.r, chipTextColor.g, chipTextColor.b, 0.38)
        : "transparent"

    scale: converterMouse.pressed ? 0.93 : (converterMouse.containsMouse ? 1.04 : 1)
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

    function currencyIndex(code) {
        for (var i = 0; i < S.Markets.converterCurrencies.length; i++) {
            if (S.Markets.converterCurrencies[i].code === code) return i;
        }
        return 0;
    }

    RowLayout {
        id: compactRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "󰩩"
            color: root.chipTextColor
            font.family: Theme.iconFontFamily
            font.pixelSize: 16
        }
        Text {
            text: S.Markets.converterFrom + " → " + S.Markets.converterTo
            color: root.chipTextColor
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
        }
    }

    MouseArea {
        id: converterMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            converterPopup.visible = !converterPopup.visible;
            if (converterPopup.visible) {
                S.Markets.ensureConverterCurrencies();
                S.Markets.requestConversion();
            }
        }
    }

    PopupWindow {
        id: converterPopup
        visible: false
        // PopupWindow does not request keyboard focus by default. Without it,
        // the amount field can be clicked but Hyprland keeps sending keys to
        // the previously focused application.
        grabFocus: true
        implicitWidth: 760
        implicitHeight: 360
        color: "transparent"

        onVisibleChanged: {
            if (visible) {
                Qt.callLater(function() {
                    popupAmount.forceActiveFocus();
                    popupAmount.selectAll();
                });
            }
        }

        anchor.window: root.QsWindow.window
        anchor.onAnchoring: {
            if (!anchor.window) return;
            var win = anchor.window;
            var itemPos = win.contentItem.mapFromItem(root, 0, 0);
            var vertical = win.height > win.width;
            if (vertical) {
                var opensLeft = Number(win.x || 0) > 100;
                converterPopup.anchor.rect.x = opensLeft ? -converterPopup.width - 6 : win.width + 6;
                converterPopup.anchor.rect.y = Math.max(6, Math.min(
                    itemPos.y + root.height / 2 - converterPopup.height / 2,
                    win.height - converterPopup.height - 6));
            } else {
                var opensUp = Number(win.y || 0) > 100;
                converterPopup.anchor.rect.x = Math.max(6, Math.min(
                    itemPos.x + root.width / 2 - converterPopup.width / 2,
                    win.width - converterPopup.width - 6));
                converterPopup.anchor.rect.y = opensUp ? -converterPopup.height - 6 : win.height + 6;
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: root.panelColor
            border.width: 1
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.48)

            MouseArea { anchors.fill: parent; z: -1 }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "󰩩"; color: root.accentColor; font.pixelSize: 23; font.family: Theme.iconFontFamily }
                    ColumnLayout {
                        spacing: 0
                        Text { text: "Currency Converter"; color: Theme.text; font.pixelSize: 17; font.bold: true; font.family: Theme.fontFamily }
                        Text {
                            text: S.Markets.converterLoading ? "Updating reference rate…" : S.Markets.converterStatus
                            color: S.Markets.converterLoading ? Theme.yellow : root.mutedColor
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "󰅖"
                        color: closeMouse.containsMouse ? Theme.red : Theme.text
                        font.pixelSize: 18
                        font.family: Theme.iconFontFamily
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: converterPopup.visible = false
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.softBorder }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    InputCard {
                        Layout.fillWidth: true
                        fieldTitle: "Amount"
                        CurrencyPicker {
                            Layout.fillWidth: true
                            currencies: S.Markets.converterCurrencies
                            selectedCode: S.Markets.converterFrom
                            onCurrencySelected: function(code) { S.Markets.setConverterPair(code, S.Markets.converterTo); }
                        }
                        TextInput {
                            id: popupAmount
                            Layout.fillWidth: true
                            text: "100"
                            color: Theme.text
                            font.pixelSize: 30
                            font.bold: true
                            font.family: Theme.fontFamily
                            selectByMouse: true
                            activeFocusOnTab: true
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            cursorVisible: activeFocus
                            validator: DoubleValidator { bottom: 0; notation: DoubleValidator.StandardNotation }
                        }
                    }

                    Rectangle {
                        width: 42; height: 42; radius: 13
                        color: swapMouse.containsMouse
                            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25)
                            : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
                        border.width: 1
                        border.color: root.accentColor
                        Text { anchors.centerIn: parent; text: "󰑕"; color: root.accentColor; font.pixelSize: 18; font.family: Theme.iconFontFamily }
                        MouseArea { id: swapMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: S.Markets.swapConverterPair() }
                    }

                    InputCard {
                        Layout.fillWidth: true
                        fieldTitle: "Converted amount"
                        CurrencyPicker {
                            Layout.fillWidth: true
                            currencies: S.Markets.converterCurrencies
                            selectedCode: S.Markets.converterTo
                            onCurrencySelected: function(code) { S.Markets.setConverterPair(S.Markets.converterFrom, code); }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: S.Markets.currencySymbol(S.Markets.converterTo) + " "
                                + S.Markets.formatConverted(S.Markets.convertedAmount(popupAmount.text))
                            color: root.accentColor
                            font.pixelSize: 30
                            font.bold: true
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "1 " + S.Markets.converterFrom + " = " + S.Markets.formatConverted(S.Markets.converterRate)
                        + " " + S.Markets.converterTo
                        + (S.Markets.converterDate.length > 0 ? "  ·  " + S.Markets.converterDate : "")
                    color: root.mutedColor
                    font.pixelSize: 12
                    font.family: Theme.fontFamily
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    component InputCard: Rectangle {
        id: inputCard
        property string fieldTitle: ""
        default property alias cardContent: inputColumn.data
        Layout.preferredHeight: 158
        radius: 13
        color: root.cardColor
        border.width: 1
        border.color: root.softBorder

        ColumnLayout {
            id: inputColumn
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            Text { text: inputCard.fieldTitle; color: root.mutedColor; font.pixelSize: 11; font.family: Theme.fontFamily }
        }
    }

    component CurrencyPicker: Basic.ComboBox {
        id: picker
        property var currencies: []
        property string selectedCode: "USD"
        signal currencySelected(string code)

        implicitHeight: 46
        model: currencies
        textRole: "code"
        currentIndex: root.currencyIndex(selectedCode)
        onActivated: function(index) { if (currencies[index]) currencySelected(currencies[index].code); }

        contentItem: Text {
            leftPadding: 13
            rightPadding: 34
            text: picker.selectedCode + "  ·  " + S.Markets.currencyName(picker.selectedCode)
            color: Theme.text
            font.pixelSize: 13
            font.bold: true
            font.family: Theme.fontFamily
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        indicator: Text {
            x: picker.width - width - 12
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅀"
            color: root.accentColor
            font.pixelSize: 14
            font.family: Theme.iconFontFamily
        }
        background: Rectangle {
            radius: 10
            color: picker.hovered
                ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.13)
                : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.04)
            border.width: 1
            border.color: picker.visualFocus ? root.accentColor : root.softBorder
        }
        delegate: Basic.ItemDelegate {
            width: picker.width
            height: 46
            highlighted: picker.highlightedIndex === index
            contentItem: RowLayout {
                spacing: 10
                Text { text: modelData.code; color: root.accentColor; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily; Layout.preferredWidth: 44 }
                Text { text: modelData.name; color: Theme.text; font.pixelSize: 12; font.family: Theme.fontFamily; Layout.fillWidth: true; elide: Text.ElideRight }
            }
            background: Rectangle {
                color: highlighted
                    ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.14)
                    : "transparent"
                radius: 6
            }
        }
        popup: Basic.Popup {
            y: picker.height + 3
            width: picker.width
            height: Math.min(276, contentItem.implicitHeight + 10)
            padding: 5
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: picker.popup.visible ? picker.delegateModel : null
                currentIndex: picker.highlightedIndex
            }
            background: Rectangle {
                color: root.panelColor
                radius: 9
                border.width: 1
                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
            }
        }
    }
}
