import QtQuick
import Qt.labs.platform
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../Widgets"
import "../../../Services" as S

Scope {
    id: root

    property string currentTemp: "--"
    property string weatherIcon: "󰖕"
    property string cityName: "Erzurum"
    property string customLat: "39.9208"
    property string customLon: "41.2746"
    property bool useFahrenheit: false
    property bool weatherEnabled: true

    property var popupData: ({
        desc: "Waiting for data...",
        feelsLike: "-",
        humidity: "-",
        wind: "-",
        sunrise: "--:--",
        sunset: "--:--",
        forecast: []
    })

    property string cachePath: StandardPaths.writableLocation(StandardPaths.CacheLocation).toString().replace("file://", "") + "/quickshell/weather.json"
    readonly property string weatherConfigPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/weather_config.json"

    // Config okuma
    Process {
        id: weatherConfigProc
        command: ["cat", root.weatherConfigPath]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { weatherConfigProc.buf += data; } }
        onExited: {
            try {
                var cfg = JSON.parse(weatherConfigProc.buf);
                var changed = false;

                if (cfg.lat && cfg.lat !== root.customLat) { root.customLat = cfg.lat; changed = true; }
                if (cfg.lon && cfg.lon !== root.customLon) { root.customLon = cfg.lon; changed = true; }
                if (cfg.city && cfg.city !== root.cityName) { root.cityName = cfg.city; }
                if (cfg.fahrenheit !== undefined && cfg.fahrenheit !== root.useFahrenheit) { root.useFahrenheit = cfg.fahrenheit; changed = true; }
                if (cfg.enabled !== undefined && cfg.enabled !== root.weatherEnabled) { root.weatherEnabled = cfg.enabled; }

                if (changed) {
                    console.log("WeatherDesktop config changed, refreshing immediately...");
                    apiProc.running = false;
                    apiProc.fullOutput = "";
                    apiProc.running = true;
                    updateTimer.restart();
                }
            } catch(e) {}
            weatherConfigProc.buf = "";
        }
    }

    Timer {
        interval: 1500; running: true; repeat: true
        onTriggered: { weatherConfigProc.buf = ""; weatherConfigProc.running = false; weatherConfigProc.running = true; }
    }

    // --- CACHE OKUMA ---
    Process {
        id: readCacheProc
        command: ["cat", root.cachePath]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var json = JSON.parse(data);
                    if (json.currentTemp) root.currentTemp = json.currentTemp;
                    if (json.icon) root.weatherIcon = json.icon;
                    if (json.popupData) root.popupData = json.popupData;
                    console.log("WeatherDesktop loaded from cache.");
                } catch(e) {
                    console.log("WeatherDesktop Cache Read Error: " + e);
                }
            }
        }
    }

    // --- CACHE YAZMA ---
    Process {
        id: writeCacheProc
        property string jsonData: ""
        command: ["bash", "-c", "mkdir -p $(dirname " + root.cachePath + ") && echo '" + jsonData + "' > " + root.cachePath]
    }

    Component.onCompleted: {
        weatherConfigProc.running = true;
        readCacheProc.running = true;
    }

    // --- VERİ ÇEKME (OpenWeatherMap) ---
    Process {
        id: apiProc
        command: ["curl", "-s", "http://api.openweathermap.org/data/2.5/forecast?lat=" + root.customLat + "&lon=" + root.customLon + "&appid=0893defca21907657083a55440bd9f71&units=" + (root.useFahrenheit ? "imperial" : "metric") + "&lang=en"]
        property string fullOutput: ""

        stdout: SplitParser {
            onRead: data => { apiProc.fullOutput += data; }
        }
        stderr: SplitParser {
            onRead: data => console.log("WeatherDesktop Curl Hatası: " + data)
        }

        onExited: {
            if (apiProc.fullOutput.trim() === "") {
                console.log("WeatherDesktop data empty, retrying in 10s...");
                // Cache'den okumayı dene
                readCacheProc.running = false;
                readCacheProc.running = true;
                
                updateTimer.interval = 10000; // Retry in 10s
                updateTimer.restart();
                return;
            }
            try {
                var json = JSON.parse(apiProc.fullOutput);

                // API Hatası Kontrolü
                if (json.cod != "200") {
                    console.log("WeatherDesktop API Error: " + json.message);
                    // Hata durumunda cache'den oku
                    readCacheProc.running = false;
                    readCacheProc.running = true;

                    updateTimer.interval = 900000; // 15 dakika bekle
                    updateTimer.restart();
                    return;
                }

                // --- GÜNCEL VERİ ---
                var current = json.list[0];
                var temp = Math.round(current.main.feels_like).toString();
                var weatherCode = current.weather[0].icon;
                var weatherDesc = current.weather[0].description;
                // İlk harfi büyüt
                weatherDesc = weatherDesc.charAt(0).toUpperCase() + weatherDesc.slice(1);

                var info = root.getWeatherInfo(weatherCode);

                root.currentTemp = temp;
                root.weatherIcon = info.icon;

                // --- 5 GÜNLÜK TAHMİN ---
                var dailyForecasts = {};
                var todayDate = new Date().getDate();

                for (var i = 0; i < json.list.length; i++) {
                    var item = json.list[i];
                    var date = new Date(item.dt * 1000);
                    var day = date.getDate();

                    if (!dailyForecasts[day]) {
                        dailyForecasts[day] = {
                            date: date,
                            min: item.main.temp_min,
                            max: item.main.temp_max,
                            icon: item.weather[0].icon
                        };
                    } else {
                        dailyForecasts[day].min = Math.min(dailyForecasts[day].min, item.main.temp_min);
                        dailyForecasts[day].max = Math.max(dailyForecasts[day].max, item.main.temp_max);
                    }
                    
                    if (date.getHours() >= 11 && date.getHours() <= 15) {
                         dailyForecasts[day].icon = item.weather[0].icon;
                    }
                }

                var forecastList = [];
                var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                
                var sortedKeys = Object.keys(dailyForecasts).sort(function(a,b){
                    return dailyForecasts[a].date - dailyForecasts[b].date;
                });

                for (var i = 0; i < sortedKeys.length; i++) {
                    var key = sortedKeys[i];
                    var data = dailyForecasts[key];
                    var dName = (data.date.getDate() === todayDate) ? "Today" : days[data.date.getDay()];
                    
                    if (forecastList.length < 5) {
                         forecastList.push({
                            day: dName,
                            max: Math.round(data.max),
                            min: Math.round(data.min),
                            icon: root.getWeatherInfo(data.icon).icon
                        });
                    }
                }

                var newData = {
                    desc: weatherDesc,
                    feelsLike: Math.round(current.main.feels_like).toString(),
                    humidity: current.main.humidity.toString(),
                    wind: Math.round(current.wind.speed).toString(),
                    sunrise: new Date(json.city.sunrise * 1000).toLocaleTimeString("tr-TR", {hour: '2-digit', minute:'2-digit'}),
                    sunset: new Date(json.city.sunset * 1000).toLocaleTimeString("tr-TR", {hour: '2-digit', minute:'2-digit'}),
                    forecast: forecastList
                };

                root.popupData = newData;
                console.log("WeatherDesktop data updated: " + root.currentTemp + "°C");

                // Cache'e yaz
                var cacheData = {
                    currentTemp: root.currentTemp,
                    icon: root.weatherIcon,
                    popupData: root.popupData,
                    lastUpdate: new Date().toLocaleString()
                };
                writeCacheProc.jsonData = JSON.stringify(cacheData);
                writeCacheProc.running = false;
                writeCacheProc.running = true;
                
                // Reset timer to normal interval on success
                updateTimer.interval = 1800000;
                updateTimer.restart();

            } catch (e) {
                console.log("WeatherDesktop JSON Error: " + e);
                // Hata durumunda cache'den oku
                readCacheProc.running = false;
                readCacheProc.running = true;

                updateTimer.interval = 60000; // 1 dakika bekle
                updateTimer.restart();
            }
            apiProc.fullOutput = "";
        }
    }

    Timer {
        id: updateTimer
        interval: 1800000
        running: true // Cache okunduktan sonra zaten çalışıyor olacak ama apiProc tetiklenmeyecek hemen
        repeat: true
        triggeredOnStart: false // İlk açılışta cache okusun, Timer hemen apiProc'u tetiklemesin
        onTriggered: {
            console.log("WeatherDesktop refreshing...");
            apiProc.running = false;
            apiProc.fullOutput = "";
            apiProc.running = true;
        }
    }

    // İlk açılışta API'yi tetiklemek için ayrı bir logic (Cache varsa bekle, yoksa hemen çek)
    // Ama şimdilik basit tutalım: Cache oku -> Timer normal döngüde API çeker.
    // Eğer cache yoksa veya eski ise, apiProc'u manuel tetikleyebiliriz.
    Timer {
        id: initTimer
        interval: 5000 // 5 saniye sonra ilk API denemesi (Cache olsa bile güncellik için)
        running: true
        repeat: false
        onTriggered: {
             apiProc.running = true;
        }
    }

    function getWeatherInfo(code) {
        // Code: "01d", "04n" etc.
        var mapping = {
            "01d": "󰖙", "01n": "󰖔", // Clear
            "02d": "󰖕", "02n": "󰖕", // Few clouds
            "03d": "󰖐", "03n": "󰖐", // Scattered clouds
            "04d": "󰖑", "04n": "󰖑", // Broken clouds
            "09d": "󰖖", "09n": "󰖖", // Shower rain
            "10d": "󰖗", "10n": "󰖗", // Rain
            "11d": "󰖓", "11n": "󰖓", // Thunderstorm
            "13d": "󰖘", "13n": "󰖘", // Snow
            "50d": "󰖑", "50n": "󰖑"  // Mist
        };
        return { icon: mapping[code] || "󰖕", text: "" };
    }

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
                            text: ""
                            color: Theme.subtext
                            font.pixelSize: 14
                            font.family: "JetBrainsMono Nerd Font"
                        }
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
                            font.family: "JetBrainsMono Nerd Font"
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
                            icon: ""
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
                            icon: ""
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
                                        font.pixelSize: 18
                                        font.family: "JetBrainsMono Nerd Font"
                                        Layout.preferredWidth: 28
                                        horizontalAlignment: Text.AlignHCenter
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
