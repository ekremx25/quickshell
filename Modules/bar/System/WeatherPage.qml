import QtQuick
import Qt.labs.platform
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"

Item {
    id: weatherPage


    // ── Config ──
    readonly property string configPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/weather_config.json"

    property bool weatherEnabled: true
    property bool useFahrenheit: false
    property bool autoLocation: false
    property string customLat: "39.9208"
    property string customLon: "41.2746"
    property string cityName: "Erzurum"
    property string searchText: ""
    property var searchResults: []
    property bool searching: false

    // ── Config okuma ──
    Process {
        id: readConfigProc
        command: ["cat", weatherPage.configPath]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { readConfigProc.buf += data; } }
        onExited: {
            try {
                var cfg = JSON.parse(readConfigProc.buf);
                if (cfg.enabled !== undefined) weatherPage.weatherEnabled = cfg.enabled;
                if (cfg.fahrenheit !== undefined) weatherPage.useFahrenheit = cfg.fahrenheit;
                if (cfg.autoLocation !== undefined) weatherPage.autoLocation = cfg.autoLocation;
                if (cfg.lat) weatherPage.customLat = cfg.lat;
                if (cfg.lon) weatherPage.customLon = cfg.lon;
                if (cfg.city) weatherPage.cityName = cfg.city;
            } catch(e) {}
            readConfigProc.buf = "";
        }
    }

    // ── Config yazma ──
    Process {
        id: writeConfigProc
        property string data: ""
        command: ["sh", "-c", "echo '" + data + "' > " + weatherPage.configPath]
    }

    function saveConfig() {
        var cfg = {
            enabled: weatherPage.weatherEnabled,
            fahrenheit: weatherPage.useFahrenheit,
            autoLocation: weatherPage.autoLocation,
            lat: weatherPage.customLat,
            lon: weatherPage.customLon,
            city: weatherPage.cityName
        };
        writeConfigProc.data = JSON.stringify(cfg);
        writeConfigProc.running = false;
        writeConfigProc.running = true;
    }

    // ── Location search via OpenWeatherMap Geo API ──
    Process {
        id: geoSearchProc
        property string buf: ""
        property string query: ""
        command: ["curl", "-s", "http://api.openweathermap.org/geo/1.0/direct?q=" + query + "&limit=5&appid=0893defca21907657083a55440bd9f71"]
        stdout: SplitParser { onRead: (data) => { geoSearchProc.buf += data; } }
        onExited: {
            weatherPage.searching = false;
            try {
                var results = JSON.parse(geoSearchProc.buf);
                var list = [];
                for (var i = 0; i < results.length; i++) {
                    var r = results[i];
                    list.push({
                        name: r.name + (r.state ? ", " + r.state : "") + ", " + (r.country || ""),
                        lat: r.lat.toFixed(4),
                        lon: r.lon.toFixed(4)
                    });
                }
                weatherPage.searchResults = list;
            } catch(e) {
                weatherPage.searchResults = [];
            }
            geoSearchProc.buf = "";
        }
    }

    // ── Auto location via IP ──
    Process {
        id: autoLocProc
        property string buf: ""
        command: ["curl", "-s", "http://ip-api.com/json/?fields=lat,lon,city"]
        stdout: SplitParser { onRead: (data) => { autoLocProc.buf += data; } }
        onExited: {
            try {
                var r = JSON.parse(autoLocProc.buf);
                if (r.lat) weatherPage.customLat = r.lat.toFixed(4);
                if (r.lon) weatherPage.customLon = r.lon.toFixed(4);
                if (r.city) weatherPage.cityName = r.city;
                saveConfig();
            } catch(e) {}
            autoLocProc.buf = "";
        }
    }

    Component.onCompleted: {
        readConfigProc.running = true;
    }

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
                Text { text: "Weather Settings"; font.bold: true; font.pixelSize: 18; color: Theme.text }
            }

            // ═══ ENABLE WEATHER ═══
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: Theme.surface
                radius: 12

                RowLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: "Show Weather"; color: Theme.text; font.bold: true; font.pixelSize: 14 }
                        Text { text: "Show weather info on bar and desktop"; color: Theme.subtext; font.pixelSize: 11 }
                    }

                    // Toggle
                    Rectangle {
                        width: 48; height: 26; radius: 13
                        color: weatherPage.weatherEnabled ? Theme.primary : Qt.rgba(49/255, 50/255, 68/255, 0.8)
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            x: weatherPage.weatherEnabled ? parent.width - width - 3 : 3
                            color: "white"
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { weatherPage.weatherEnabled = !weatherPage.weatherEnabled; saveConfig(); }
                        }
                    }
                }
            }

            // ═══ USE FAHRENHEIT ═══
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: Theme.surface
                radius: 12

                RowLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: "Use Fahrenheit"; color: Theme.text; font.bold: true; font.pixelSize: 14 }
                        Text { text: "Show Fahrenheit instead of Celsius"; color: Theme.subtext; font.pixelSize: 11 }
                    }

                    Rectangle {
                        width: 48; height: 26; radius: 13
                        color: weatherPage.useFahrenheit ? Theme.primary : Qt.rgba(49/255, 50/255, 68/255, 0.8)
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            x: weatherPage.useFahrenheit ? parent.width - width - 3 : 3
                            color: "white"
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { weatherPage.useFahrenheit = !weatherPage.useFahrenheit; saveConfig(); }
                        }
                    }
                }
            }

            // ═══ AUTO LOCATION ═══
            Rectangle {
                Layout.fillWidth: true
                height: 80
                color: Theme.surface
                radius: 12

                RowLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: "Auto Location"; color: Theme.text; font.bold: true; font.pixelSize: 14 }
                        Text { text: "Determine location automatically via IP"; color: Theme.subtext; font.pixelSize: 11 }
                    }

                    Rectangle {
                        width: 48; height: 26; radius: 13
                        color: weatherPage.autoLocation ? Theme.primary : Qt.rgba(49/255, 50/255, 68/255, 0.8)
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            x: weatherPage.autoLocation ? parent.width - width - 3 : 3
                            color: "white"
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                weatherPage.autoLocation = !weatherPage.autoLocation;
                                if (weatherPage.autoLocation) {
                                    autoLocProc.buf = "";
                                    autoLocProc.running = true;
                                }
                                saveConfig();
                            }
                        }
                    }
                }
            }

            // ═══ MEVCUT KONUM BİLGİSİ ═══
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
                        Text { text: "📍 " + weatherPage.cityName; color: Theme.text; font.bold: true; font.pixelSize: 14 }
                        Item { Layout.fillWidth: true }
                        Text { text: weatherPage.customLat + "°, " + weatherPage.customLon + "°"; color: Theme.subtext; font.pixelSize: 11 }
                    }
                }
            }

            // ═══ CUSTOM LOCATION ═══
            Text {
                text: "Custom Location"
                color: Theme.text; font.bold: true; font.pixelSize: 13
                visible: !weatherPage.autoLocation
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: !weatherPage.autoLocation

                // Latitude
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { text: "Latitude"; color: Theme.subtext; font.pixelSize: 11 }
                    Rectangle {
                        Layout.fillWidth: true; height: 40; radius: 8
                        color: Qt.rgba(49/255, 50/255, 68/255, 0.6)
                        border.color: latInput.activeFocus ? Theme.primary : "transparent"
                        border.width: latInput.activeFocus ? 2 : 0

                        TextInput {
                            id: latInput
                            anchors.fill: parent; anchors.margins: 10
                            text: weatherPage.customLat
                            color: Theme.text; font.pixelSize: 13
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
                    Text { text: "Longitude"; color: Theme.subtext; font.pixelSize: 11 }
                    Rectangle {
                        Layout.fillWidth: true; height: 40; radius: 8
                        color: Qt.rgba(49/255, 50/255, 68/255, 0.6)
                        border.color: lonInput.activeFocus ? Theme.primary : "transparent"
                        border.width: lonInput.activeFocus ? 2 : 0

                        TextInput {
                            id: lonInput
                            anchors.fill: parent; anchors.margins: 10
                            text: weatherPage.customLon
                            color: Theme.text; font.pixelSize: 13
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
                color: Theme.text; font.bold: true; font.pixelSize: 13
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
                        color: Theme.subtext
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        text: weatherPage.searchText
                        color: Theme.text; font.pixelSize: 13
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        onTextChanged: weatherPage.searchText = text

                        Text {
                            anchors.fill: parent
                            text: "İstanbul, Ankara, London..."
                            color: Theme.overlay
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            visible: searchInput.text === "" && !searchInput.activeFocus
                        }

                        onAccepted: {
                            if (weatherPage.searchText.trim() !== "") {
                                weatherPage.searching = true;
                                weatherPage.searchResults = [];
                                geoSearchProc.query = weatherPage.searchText.trim().replace(/ /g, "+");
                                geoSearchProc.buf = "";
                                geoSearchProc.running = false;
                                geoSearchProc.running = true;
                            }
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
                            onClicked: {
                                if (weatherPage.searchText.trim() !== "") {
                                    weatherPage.searching = true;
                                    weatherPage.searchResults = [];
                                    geoSearchProc.query = weatherPage.searchText.trim().replace(/ /g, "+");
                                    geoSearchProc.buf = "";
                                    geoSearchProc.running = false;
                                    geoSearchProc.running = true;
                                }
                            }
                        }
                    }
                }
            }

            // ═══ SEARCH RESULTS ═══
            Text {
                text: weatherPage.searching ? "Searching..." : ""
                color: Theme.subtext; font.pixelSize: 12
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
                            color: Theme.text; font.pixelSize: 13; font.bold: true
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.lat + "°, " + modelData.lon + "°"
                            color: Theme.subtext; font.pixelSize: 11
                        }

                        Rectangle {
                            width: 60; height: 28; radius: 6
                            color: selectMA.containsMouse ? Qt.lighter("#a6e3a1", 1.2) : "#a6e3a1"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { anchors.centerIn: parent; text: "Select"; color: "#1e1e2e"; font.pixelSize: 11; font.bold: true }
                            MouseArea {
                                id: selectMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    weatherPage.customLat = modelData.lat;
                                    weatherPage.customLon = modelData.lon;
                                    weatherPage.cityName = modelData.name.split(",")[0].trim();
                                    weatherPage.searchResults = [];
                                    weatherPage.searchText = "";
                                    saveConfig();
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: resultMA; anchors.fill: parent; hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }

            // ═══ KAYDET VE UYGULA ═══
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.06) }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Weather will refresh after saving settings"
                    color: Theme.overlay; font.pixelSize: 11
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 160; height: 40; radius: 10
                    color: applyMA.containsMouse ? Qt.lighter(Theme.primary, 1.2) : Theme.primary
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text { anchors.centerIn: parent; text: "💾  Save & Apply"; color: "#1e1e2e"; font.pixelSize: 13; font.bold: true }
                    MouseArea {
                        id: applyMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { saveConfig(); }
                    }
                }
            }

            Item { height: 20 }
        }
    }
}
