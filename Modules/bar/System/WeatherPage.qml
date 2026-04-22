import QtQuick
import Qt.labs.platform
import QtQuick.Layouts
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette

Item {
    id: weatherPage
    WeatherSettingsService { id: weatherService }

    property alias weatherEnabled: weatherService.weatherEnabled
    property alias useFahrenheit: weatherService.useFahrenheit
    property alias autoLocation: weatherService.autoLocation
    property alias customLat: weatherService.customLat
    property alias customLon: weatherService.customLon
    property alias cityName: weatherService.cityName
    property alias searchText: weatherService.searchText
    property alias searchResults: weatherService.searchResults
    property alias searching: weatherService.searching

    // ── UI ──
    Flickable {
        anchors.fill: parent
        contentHeight: mainCol.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainCol
            width: parent.width
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 20; anchors.rightMargin: 20
            anchors.top: parent.top; anchors.topMargin: 20
            spacing: 16

            // ═══ HEADER ═══
            RowLayout {
                Layout.fillWidth: true
                Text { text: "󰖕"; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: "#f9e2af" }
                Text { text: "Weather Settings"; font.bold: true; font.pixelSize: 18; color: SettingsPalette.text }
            }

            // ═══ ENABLE WEATHER ═══
            SettingsToggleCard {
                title: "Show Weather"
                description: "Show weather info on bar and desktop"
                checked: weatherPage.weatherEnabled
                onToggle: function() {
                    weatherPage.weatherEnabled = !weatherPage.weatherEnabled;
                    weatherService.saveConfig();
                }
            }

            // ═══ USE FAHRENHEIT ═══
            SettingsToggleCard {
                title: "Use Fahrenheit"
                description: "Show Fahrenheit instead of Celsius"
                checked: weatherPage.useFahrenheit
                onToggle: function() {
                    weatherPage.useFahrenheit = !weatherPage.useFahrenheit;
                    weatherService.saveConfig();
                }
            }

            // ═══ AUTO LOCATION ═══
            SettingsToggleCard {
                title: "Auto Location"
                description: "Determine location automatically via IP"
                checked: weatherPage.autoLocation
                onToggle: function() {
                    weatherService.toggleAutoLocation();
                }
            }

            // ═══ CURRENT LOCATION INFO ═══
            Rectangle {
                Layout.fillWidth: true
                height: currentLocCol.height + 24
                color: Qt.rgba(166/255, 227/255, 161/255, 0.08)
                radius: 12
                border.color: Qt.rgba(166/255, 227/255, 161/255, 0.2)
                border.width: 1

                ColumnLayout {
                    id: currentLocCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 12
                    spacing: 6

                    RowLayout {
                        spacing: 8
                        Text { text: ""; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: "#a6e3a1" }
                        Text { text: "Current Location"; color: "#a6e3a1"; font.bold: true; font.pixelSize: 13 }
                    }

                    RowLayout {
                        spacing: 16
                        Layout.fillWidth: true
                        Text { text: "📍 " + weatherPage.cityName; color: SettingsPalette.text; font.bold: true; font.pixelSize: 14 }
                        Item { Layout.fillWidth: true }
                        Text { text: weatherPage.customLat + "°, " + weatherPage.customLon + "°"; color: SettingsPalette.subtext; font.pixelSize: 11 }
                    }
                }
            }

            // ═══ CUSTOM LOCATION ═══
            Text {
                text: "Custom Location"
                color: SettingsPalette.text; font.bold: true; font.pixelSize: 13
                visible: !weatherPage.autoLocation
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: !weatherPage.autoLocation

                // Latitude
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { text: "Latitude"; color: SettingsPalette.subtext; font.pixelSize: 11 }
                    Rectangle {
                        Layout.fillWidth: true; height: 40; radius: 8
                        color: Qt.rgba(49/255, 50/255, 68/255, 0.6)
                        border.color: latInput.activeFocus ? Theme.primary : "transparent"
                        border.width: latInput.activeFocus ? 2 : 0

                        TextInput {
                            id: latInput
                            anchors.fill: parent; anchors.margins: 10
                            text: weatherPage.customLat
                            color: SettingsPalette.text; font.pixelSize: 13
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            onTextChanged: weatherPage.customLat = text
                            onEditingFinished: saveConfig()
                        }
                    }
                }

                // Longitude
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { text: "Longitude"; color: SettingsPalette.subtext; font.pixelSize: 11 }
                    Rectangle {
                        Layout.fillWidth: true; height: 40; radius: 8
                        color: Qt.rgba(49/255, 50/255, 68/255, 0.6)
                        border.color: lonInput.activeFocus ? Theme.primary : "transparent"
                        border.width: lonInput.activeFocus ? 2 : 0

                        TextInput {
                            id: lonInput
                            anchors.fill: parent; anchors.margins: 10
                            text: weatherPage.customLon
                            color: SettingsPalette.text; font.pixelSize: 13
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            onTextChanged: weatherPage.customLon = text
                            onEditingFinished: saveConfig()
                        }
                    }
                }
            }

            // ═══ LOCATION SEARCH ═══
            Text {
                text: "Search City"
                color: SettingsPalette.text; font.bold: true; font.pixelSize: 13
                visible: !weatherPage.autoLocation
            }

            Rectangle {
                Layout.fillWidth: true; height: 44; radius: 10
                color: Qt.rgba(49/255, 50/255, 68/255, 0.6)
                border.color: searchInput.activeFocus ? Theme.primary : "transparent"
                border.width: searchInput.activeFocus ? 2 : 0
                visible: !weatherPage.autoLocation

                RowLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 8

                    Text {
                        text: "🔍"
                        font.pixelSize: 14
                        color: SettingsPalette.subtext
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                            text: weatherPage.searchText
                            color: SettingsPalette.text; font.pixelSize: 13
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            onTextChanged: weatherPage.searchText = text

                        Text {
                            anchors.fill: parent
                            text: "Istanbul, London, Tokyo..."
                            color: SettingsPalette.overlay
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            visible: searchInput.text === "" && !searchInput.activeFocus
                        }

                        onAccepted: {
                            weatherService.searchCity();
                        }
                    }

                    // Search button
                    Rectangle {
                        width: 70; height: 28; radius: 6
                        color: searchBtnMA.containsMouse ? Qt.lighter(Theme.primary, 1.2) : Theme.primary
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: "Search"; color: "#1e1e2e"; font.pixelSize: 12; font.bold: true }
                        MouseArea {
                            id: searchBtnMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: weatherService.searchCity()
                        }
                    }
                }
            }

            // ═══ SEARCH RESULTS ═══
            Text {
                text: weatherPage.searching ? "Searching..." : ""
                color: SettingsPalette.subtext; font.pixelSize: 12
                visible: weatherPage.searching
            }

            Repeater {
                model: weatherPage.searchResults
                Rectangle {
                    Layout.fillWidth: true
                    height: 48; radius: 10
                    color: resultMA.containsMouse ? Qt.rgba(137/255, 180/255, 250/255, 0.12) : Qt.rgba(49/255, 50/255, 68/255, 0.4)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 10
                        Text { text: "📍"; font.pixelSize: 14 }
                        Text {
                            text: modelData.name
                            color: SettingsPalette.text; font.pixelSize: 13; font.bold: true
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.lat + "°, " + modelData.lon + "°"
                            color: SettingsPalette.subtext; font.pixelSize: 11
                        }

                        Rectangle {
                            width: 60; height: 28; radius: 6
                            color: selectMA.containsMouse ? Qt.lighter("#a6e3a1", 1.2) : "#a6e3a1"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { anchors.centerIn: parent; text: "Select"; color: "#1e1e2e"; font.pixelSize: 11; font.bold: true }
                            MouseArea {
                                id: selectMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: weatherService.selectSearchResult(modelData)
                            }
                        }
                    }

                    MouseArea {
                        id: resultMA; anchors.fill: parent; hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }

            // ═══ SAVE AND APPLY ═══
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.06) }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Weather will refresh after saving settings"
                    color: SettingsPalette.overlay; font.pixelSize: 11
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 160; height: 40; radius: 10
                    color: applyMA.containsMouse ? Qt.lighter(Theme.primary, 1.2) : Theme.primary
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text { anchors.centerIn: parent; text: "💾  Save & Apply"; color: "#1e1e2e"; font.pixelSize: 13; font.bold: true }
                    MouseArea {
                        id: applyMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: weatherService.saveConfig()
                    }
                }
            }

            Item { height: 20 }
        }
    }
}
