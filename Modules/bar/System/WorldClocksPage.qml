import QtQuick
import QtQuick.Layouts
import "../../../Widgets"

Item {
    id: page

    WeatherSettingsService { id: service }

    function countryCountText() {
        return service.countries.length > 0 ? service.countries.length + " countries available" : "Loading countries...";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text { text: "󱑂"; font.pixelSize: 21; font.family: Theme.iconFontFamily; color: Theme.primary }
            ColumnLayout {
                spacing: 1
                Text { text: "World Clocks"; font.bold: true; font.pixelSize: 18; color: SettingsPalette.text; font.family: Theme.fontFamily }
                Text { text: "Choose a country, find a city, and add its local time and weather to your desktop"; font.pixelSize: 11; color: SettingsPalette.subtext; font.family: Theme.fontFamily }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: enabledText.width + 28
                height: 30
                radius: 15
                color: service.worldClockEnabled ? Theme.withAlpha(Theme.green, 0.14) : Theme.withAlpha(Theme.red, 0.14)
                border.width: 1
                border.color: service.worldClockEnabled ? Theme.green : Theme.red
                Text {
                    id: enabledText
                    anchors.centerIn: parent
                    text: service.worldClockEnabled ? "● Desktop active" : "○ Desktop hidden"
                    color: service.worldClockEnabled ? Theme.green : Theme.red
                    font.pixelSize: 10
                    font.bold: true
                    font.family: Theme.fontFamily
                }
            }
        }

        SettingsToggleCard {
            Layout.fillWidth: true
            title: "Show World Clocks"
            description: "Display the compact local-time and weather card on the desktop"
            checked: service.worldClockEnabled
            onToggle: function() {
                service.worldClockEnabled = !service.worldClockEnabled;
                service.saveConfig();
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // ── Country selector ──────────────────────────────────────
            Rectangle {
                Layout.preferredWidth: Math.max(300, page.width * 0.34)
                Layout.fillHeight: true
                radius: 14
                color: Theme.withAlpha(Theme.surface, 0.38)
                border.width: 1
                border.color: Theme.withAlpha(Theme.text, 0.06)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Countries"; color: SettingsPalette.text; font.pixelSize: 14; font.bold: true; font.family: Theme.fontFamily }
                        Item { Layout.fillWidth: true }
                        Text { text: page.countryCountText(); color: SettingsPalette.overlay; font.pixelSize: 9; font.family: Theme.fontFamily }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 9
                        color: Theme.withAlpha(Theme.background, 0.62)
                        border.width: countryFilter.activeFocus ? 2 : 1
                        border.color: countryFilter.activeFocus ? Theme.primary : Theme.withAlpha(Theme.text, 0.05)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            spacing: 8
                            Text { text: "󰍉"; color: SettingsPalette.subtext; font.pixelSize: 13; font.family: Theme.iconFontFamily }
                            TextInput {
                                id: countryFilter
                                Layout.fillWidth: true
                                color: SettingsPalette.text
                                font.pixelSize: 12
                                font.family: Theme.fontFamily
                                selectByMouse: true
                                verticalAlignment: TextInput.AlignVCenter
                                Text {
                                    anchors.fill: parent
                                    visible: countryFilter.text.length === 0 && !countryFilter.activeFocus
                                    text: "Search all countries..."
                                    color: SettingsPalette.overlay
                                    font.pixelSize: 12
                                    font.family: Theme.fontFamily
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }

                    ListView {
                        id: countryList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: service.filterCountries(countryFilter.text)

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: countryList.width
                            height: 38
                            radius: 8
                            property bool selected: service.selectedCountryCode === modelData.code
                            color: selected
                                   ? Theme.withAlpha(Theme.primary, 0.19)
                                   : countryMA.containsMouse ? Theme.withAlpha(Theme.text, 0.06) : "transparent"
                            border.width: selected ? 1 : 0
                            border.color: selected ? Theme.primary : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 9
                                spacing: 9
                                Rectangle {
                                    width: 30; height: 22; radius: 6
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.13)
                                    Text { anchors.centerIn: parent; text: modelData.code; color: Theme.primary; font.pixelSize: 9; font.bold: true; font.family: Theme.fontFamily }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: selected ? Theme.primary : SettingsPalette.text
                                    font.pixelSize: 11
                                    font.bold: selected
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                }
                                Text { visible: selected; text: "󰄬"; color: Theme.green; font.pixelSize: 12; font.family: Theme.iconFontFamily }
                            }

                            MouseArea {
                                id: countryMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: service.selectCountry(modelData)
                            }
                        }
                    }
                }
            }

            // ── City search and configured clocks ────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: Theme.withAlpha(Theme.surface, 0.28)
                border.width: 1
                border.color: Theme.withAlpha(Theme.text, 0.06)

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 12
                    contentHeight: rightColumn.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: rightColumn
                        width: parent.width
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: service.selectedCountryCode.length > 0
                                      ? "Cities in " + service.selectedCountryName
                                      : "Select a country"
                                color: SettingsPalette.text
                                font.pixelSize: 14
                                font.bold: true
                                font.family: Theme.fontFamily
                            }
                            Item { Layout.fillWidth: true }
                            Text { text: service.worldClocks.length + " / 8 clocks"; color: SettingsPalette.subtext; font.pixelSize: 10; font.family: Theme.fontFamily }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 42
                            radius: 9
                            color: Theme.withAlpha(Theme.background, 0.62)
                            border.width: cityInput.activeFocus ? 2 : 1
                            border.color: cityInput.activeFocus ? Theme.primary : Theme.withAlpha(Theme.text, 0.05)
                            opacity: service.selectedCountryCode.length > 0 ? 1 : 0.45

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 11
                                anchors.rightMargin: 7
                                spacing: 8
                                Text { text: "󰍉"; color: SettingsPalette.subtext; font.pixelSize: 13; font.family: Theme.iconFontFamily }
                                TextInput {
                                    id: cityInput
                                    Layout.fillWidth: true
                                    enabled: service.selectedCountryCode.length > 0
                                    text: service.searchText
                                    onTextChanged: service.searchText = text
                                    onAccepted: service.searchCity()
                                    color: SettingsPalette.text
                                    font.pixelSize: 12
                                    font.family: Theme.fontFamily
                                    selectByMouse: true
                                    verticalAlignment: TextInput.AlignVCenter
                                    Text {
                                        anchors.fill: parent
                                        visible: cityInput.text.length === 0 && !cityInput.activeFocus
                                        text: service.selectedCountryCode.length > 0 ? "Type a city name..." : "Choose a country first"
                                        color: SettingsPalette.overlay
                                        font.pixelSize: 12
                                        font.family: Theme.fontFamily
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Rectangle {
                                    width: 74; height: 28; radius: 7
                                    color: searchMA.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary
                                    opacity: service.selectedCountryCode.length > 0 && service.searchText.trim().length > 0 ? 1 : 0.4
                                    Text { anchors.centerIn: parent; text: service.searching ? "..." : "Search"; color: Theme.foregroundFor(Theme.primary); font.pixelSize: 10; font.bold: true; font.family: Theme.fontFamily }
                                    MouseArea {
                                        id: searchMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: service.selectedCountryCode.length > 0 && service.searchText.trim().length > 0 && !service.searching
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: service.searchCity()
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: service.searching
                            text: "Searching cities in " + service.selectedCountryName + "..."
                            color: SettingsPalette.subtext
                            font.pixelSize: 10
                            font.family: Theme.fontFamily
                        }

                        Repeater {
                            model: service.searchResults
                            Rectangle {
                                Layout.fillWidth: true
                                height: 50
                                radius: 9
                                color: resultMA.containsMouse ? Theme.withAlpha(Theme.primary, 0.12) : Theme.withAlpha(Theme.text, 0.035)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 11
                                    anchors.rightMargin: 8
                                    spacing: 9
                                    Text { text: "󰍎"; color: Theme.primary; font.pixelSize: 14; font.family: Theme.iconFontFamily }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text { text: modelData.city; color: SettingsPalette.text; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                                        Text {
                                            Layout.fillWidth: true
                                            text: (modelData.name || modelData.city) + "  ·  " + modelData.timezone
                                            color: SettingsPalette.subtext; font.pixelSize: 9; font.family: Theme.fontFamily; elide: Text.ElideRight
                                        }
                                    }
                                    Rectangle {
                                        width: 86; height: 28; radius: 7
                                        color: addMA.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary
                                        opacity: service.canAddWorldClock(modelData) ? 1 : 0.38
                                        Text { anchors.centerIn: parent; text: service.canAddWorldClock(modelData) ? "Add clock" : "Added"; color: Theme.foregroundFor(Theme.primary); font.pixelSize: 10; font.bold: true; font.family: Theme.fontFamily }
                                        MouseArea {
                                            id: addMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: service.canAddWorldClock(modelData)
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: service.addWorldClock(modelData)
                                        }
                                    }
                                }
                                MouseArea { id: resultMA; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.withAlpha(Theme.text, 0.06); Layout.topMargin: 4 }

                        Text { text: "Desktop clocks"; color: SettingsPalette.text; font.pixelSize: 13; font.bold: true; font.family: Theme.fontFamily }

                        Text {
                            Layout.fillWidth: true
                            visible: service.worldClocks.length === 0
                            text: "No clocks yet. Choose a country and add a city above."
                            color: SettingsPalette.overlay
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                        }

                        Repeater {
                            model: service.worldClocks
                            Rectangle {
                                Layout.fillWidth: true
                                height: 52
                                radius: 9
                                color: Theme.withAlpha(Theme.text, 0.04)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 11
                                    anchors.rightMargin: 7
                                    spacing: 8
                                    Rectangle {
                                        width: 34; height: 34; radius: 10
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                        Text { anchors.centerIn: parent; text: "󱑂"; color: Theme.primary; font.pixelSize: 14; font.family: Theme.iconFontFamily }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text { text: modelData.city; color: SettingsPalette.text; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                                        Text { text: (modelData.country || "") + "  ·  " + (modelData.timezone || ""); color: SettingsPalette.subtext; font.pixelSize: 9; font.family: Theme.fontFamily }
                                    }
                                    Rectangle {
                                        width: 28; height: 28; radius: 7; opacity: index > 0 ? 1 : 0.3
                                        color: upMA.containsMouse ? Theme.withAlpha(Theme.primary, 0.18) : "transparent"
                                        Text { anchors.centerIn: parent; text: "󰁝"; color: SettingsPalette.text; font.pixelSize: 12; font.family: Theme.iconFontFamily }
                                        MouseArea { id: upMA; anchors.fill: parent; enabled: index > 0; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: service.moveWorldClock(index, -1) }
                                    }
                                    Rectangle {
                                        width: 28; height: 28; radius: 7; opacity: index < service.worldClocks.length - 1 ? 1 : 0.3
                                        color: downMA.containsMouse ? Theme.withAlpha(Theme.primary, 0.18) : "transparent"
                                        Text { anchors.centerIn: parent; text: "󰁅"; color: SettingsPalette.text; font.pixelSize: 12; font.family: Theme.iconFontFamily }
                                        MouseArea { id: downMA; anchors.fill: parent; enabled: index < service.worldClocks.length - 1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: service.moveWorldClock(index, 1) }
                                    }
                                    Rectangle {
                                        width: 32; height: 28; radius: 7
                                        color: removeMA.containsMouse ? Theme.withAlpha(Theme.red, 0.2) : "transparent"
                                        Text { anchors.centerIn: parent; text: "󰆴"; color: Theme.red; font.pixelSize: 13; font.family: Theme.iconFontFamily }
                                        MouseArea { id: removeMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: service.removeWorldClock(index) }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: service.worldClockStatus.length > 0
                            text: service.worldClockStatus
                            color: Theme.primary
                            font.pixelSize: 10
                            font.family: Theme.fontFamily
                        }

                        Item { height: 4 }
                    }
                }
            }
        }
    }
}
