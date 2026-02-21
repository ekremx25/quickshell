import QtQuick
import Qt.labs.platform
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"

Rectangle {
    id: root

    // Theme { id: Theme } // Removed for Singleton

    // --- BAR GÖRÜNÜMÜ ---
    radius: menu.visible ? 4 : 17
    implicitWidth: barRow.implicitWidth + 24
    implicitHeight: 34
    color: Theme.weatherColor // Renk değişimi


    RowLayout {
        id: barRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.weatherIcon
            color: "#1e1e2e"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
        }

        Text {
            // "24°C • Açık" formatı
            text: (root.currentTemp != "-" ? root.currentTemp + (root.useFahrenheit ? "°F" : "°C") : "-") + 
                  (root.popupData && root.popupData.desc ? " • " + root.popupData.desc : "")
            color: "#1e1e2e"
            font.bold: true
            font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font"
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            menu.visible = !menu.visible
            // Tıklayınca veriyi zorla yenile (Debug için iyi olur)
            if (menu.visible) {
                console.log("Hava durumu yenileniyor...");
                apiProc.running = false;
                apiProc.running = true;
            }
        }
    }

    // --- MENÜ (PopupWindow) ---
    PopupWindow {
        id: menu
        visible: false
        implicitWidth: 480
        implicitHeight: 540

        anchor {
            window: root.QsWindow.window
            onAnchoring: {
                if (!root.QsWindow || !root.QsWindow.window) return;
                var win = root.QsWindow.window.contentItem;
                menu.anchor.rect = win.mapFromItem(root, -(menu.width/2 - root.width/2), root.height + 4, root.width, root.height);
            }
        }

        MouseArea {
            anchors.fill: parent
            onPressed: (mouse) => { if (!bg.contains(Qt.point(mouse.x, mouse.y))) menu.visible = false; }
        }

        Rectangle {
            id: bg
            anchors.fill: parent
            color: Theme.background
            border.color: Theme.surface
            border.width: 1
            radius: Theme.radius

            // Kapatma Butonu
            Text {
                text: "󰅖"
                color: Theme.text
                font.pixelSize: 22
                font.family: "JetBrainsMono Nerd Font"
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 15
                z: 10 // Üstte görünsün

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menu.visible = false
                    hoverEnabled: true
                    onEntered: parent.color = Theme.red
                    onExited: parent.color = Theme.text
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                // 1. ÜST KISIM
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20
                    Text {
                        text: root.weatherIcon
                        color: Theme.primary
                        font.pixelSize: 64
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            spacing: 5
                            Text { text: (root.popupData && root.popupData.feelsLike ? root.popupData.feelsLike : "-"); color: Theme.text; font.pixelSize: 36; font.bold: true }
                            Text { text: "°"; color: Theme.primary; font.pixelSize: 20; font.bold: true; Layout.alignment: Qt.AlignTop | Qt.AlignLeft; Layout.topMargin: 4 }
                        }
                        Text { text: "Feels like"; color: Theme.overlay2; font.pixelSize: 11 }
                        Text { text: root.currentTemp + (root.useFahrenheit ? "°F" : "°C"); color: Theme.subtext; font.pixelSize: 14 }
                        Text {
                            text: (root.popupData && root.popupData.desc ? root.popupData.desc : "")
                            color: Theme.text
                            font.pixelSize: 16
                            font.bold: true
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        Text { text: " " + root.cityName; color: Theme.subtext; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

                // 2. DETAYLAR
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 15
                    columnSpacing: 30
                    DetailRow { icon: ""; label: "Humidity"; value: "%" + (root.popupData && root.popupData.humidity ? root.popupData.humidity : "-"); iconColor: Theme.primary }
                    DetailRow { icon: "󰖝"; label: "Wind"; value: (root.popupData && root.popupData.wind ? root.popupData.wind : "-") + " km/h"; iconColor: Theme.primary }
                    DetailRow { icon: ""; label: "Sunrise"; value: (root.popupData && root.popupData.sunrise ? root.popupData.sunrise : "-"); iconColor: "#f9e2af" }
                    DetailRow { icon: ""; label: "Sunset"; value: (root.popupData && root.popupData.sunset ? root.popupData.sunset : "-"); iconColor: "#f38ba8" }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

                // 3. 7 GÜNLÜK TAHMİN
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12
                    Repeater {
                        model: (root.popupData && root.popupData.forecast ? root.popupData.forecast : [])
                        ColumnLayout {
                            spacing: 5
                            Layout.alignment: Qt.AlignHCenter
                            Text { text: modelData.day; color: Theme.subtext; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
                            Text { text: modelData.icon; color: Theme.primary; font.pixelSize: 22; font.family: "JetBrainsMono Nerd Font"; Layout.alignment: Qt.AlignHCenter }
                            Text { text: modelData.min + "°/" + modelData.max + "°"; color: Theme.text; font.pixelSize: 10; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                        }
                    }
                }
            }
        }
    }

    component DetailRow : RowLayout {
        property string icon
        property string label
        property string value
        property color iconColor
        spacing: 10
        Text { text: icon; color: iconColor; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
        ColumnLayout {
            spacing: 2
            Text { text: label; color: Theme.subtext; font.pixelSize: 11 }
            Text { text: value; color: Theme.text; font.pixelSize: 13; font.bold: true }
        }
    }

    property var popupData: ({})
    property string currentTemp: "-"
    property string weatherIcon: ""
    property string cachePath: StandardPaths.writableLocation(StandardPaths.CacheLocation).toString().replace("file://", "") + "/quickshell/weather.json"

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
                    console.log("Hava durumu önbellekten yüklendi.");
                } catch(e) {
                    console.log("Önbellek okuma hatası: " + e);
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
        // weatherConfigProc.running = true; // Removed invalid reference
        readCacheProc.running = true;
    }

    // --- VERİ ÇEKME İŞLEMİ ---
    Process {
        id: apiProc
        // OpenWeatherMap Forecast
        command: ["curl", "-s", "http://api.openweathermap.org/data/2.5/forecast?lat=" + root.customLat + "&lon=" + root.customLon + "&appid=0893defca21907657083a55440bd9f71&units=" + (root.useFahrenheit ? "imperial" : "metric") + "&lang=en"]

        property string fullOutput: ""

        stdout: SplitParser {
            onRead: data => {
                apiProc.fullOutput += data;
            }
        }

        // Hata ayıklama için stderr'i de dinleyelim
        stderr: SplitParser {
            onRead: data => console.log("Hava Durumu Curl Hatası: " + data)
        }

        onExited: {
            if (apiProc.fullOutput.trim() === "") {
                console.log("Hava durumu boş veri döndürdü! 1 dk sonra tekrar denenecek.");
                updateTimer.interval = 60000;
                updateTimer.restart();
                return;
            }

            try {
                var json = JSON.parse(apiProc.fullOutput);

                // API Hatası Kontrolü
                if (json.cod != "200") {
                    console.log("Hava Durumu API Hatası: " + json.message);
                    updateTimer.interval = 900000; // 15 dakika bekle
                    updateTimer.restart();
                    return;
                }

                // --- GÜNCEL VERİ (İlk kayıt - yaklaşık) ---
                var current = json.list[0];
                var temp = Math.round(current.main.feels_like).toString();
                var weatherCode = current.weather[0].icon; 
                var weatherDesc = current.weather[0].description;
                // İlk harfi büyüt
                weatherDesc = weatherDesc.charAt(0).toUpperCase() + weatherDesc.slice(1);

                var info = getWeatherInfo(weatherCode);

                root.currentTemp = temp;
                root.weatherIcon = info.icon;
                
                // KULLANICININ İSTEĞİ: Sadece "Açık", "Bulutlu" gibi kısa bilgi (info.text)
                // weatherDesc = weatherDesc.charAt(0).toUpperCase() + weatherDesc.slice(1);
                weatherDesc = info.text;

                // --- 5 GÜNLÜK TAHMİN ---
                // OpenWeatherMap 3 saatlik veri verir, bunları günlere göre gruplayıp max/min bulmalıyız.
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
                    
                    // Öğle saati (11:00 - 15:00) ikonunu tercih et, yoksa ilkini kullan
                    if (date.getHours() >= 11 && date.getHours() <= 15) {
                         dailyForecasts[day].icon = item.weather[0].icon;
                    }
                }

                var forecastList = [];
                var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                
                // Sort (Date based)
                var sortedKeys = Object.keys(dailyForecasts).sort(function(a,b){
                    return dailyForecasts[a].date - dailyForecasts[b].date;
                });

                for (var i = 0; i < sortedKeys.length; i++) {
                    var key = sortedKeys[i];
                    var data = dailyForecasts[key];
                    // Get next days excluding today (usually fits 5 days)
                    // Or include today, let UI say "Today"
                    var dName = (data.date.getDate() === todayDate) ? "Today" : days[data.date.getDay()];
                    
                    if (forecastList.length < 5) {
                         forecastList.push({
                            day: dName,
                            max: Math.round(data.max),
                            min: Math.round(data.min),
                            icon: getWeatherInfo(data.icon).icon
                        });
                    }
                }

                var newPopupData = {
                    desc: weatherDesc,
                    feelsLike: Math.round(current.main.feels_like).toString(),
                    humidity: current.main.humidity.toString(),
                    wind: Math.round(current.wind.speed).toString(),
                    sunrise: new Date(json.city.sunrise * 1000).toLocaleTimeString("tr-TR", {hour: '2-digit', minute:'2-digit'}),
                    sunset: new Date(json.city.sunset * 1000).toLocaleTimeString("tr-TR", {hour: '2-digit', minute:'2-digit'}),
                    forecast: forecastList
                };

                root.popupData = newPopupData;

                // Cache Yazma
                var cacheData = {
                    currentTemp: root.currentTemp,
                    icon: root.weatherIcon,
                    popupData: root.popupData,
                    lastUpdate: new Date().toLocaleString()
                };
                writeCacheProc.jsonData = JSON.stringify(cacheData);
                writeCacheProc.running = false;
                writeCacheProc.running = true;

                updateTimer.interval = 1800000;
                updateTimer.restart();

            } catch (e) {
                console.log("Hava durumu JSON Hatası: " + e);
                console.log("Veri: " + apiProc.fullOutput.substring(0, 100) + "..."); 
                
                updateTimer.interval = 60000; // Hata durumunda 1 dk sonra dene
                updateTimer.restart();
            }

            // Temizlik
            apiProc.fullOutput = "";
        }
    }

    // İlk açılışta biraz bekle (5 sn) sonra veriyi çek (Ağ bağlantısı için)
    Timer {
        id: initTimer
        interval: 5000
        running: true
        repeat: false
        onTriggered: {
            console.log("Hava durumu ilk güncelleme (5sn gecikmeli)...");
            apiProc.running = true;
            updateTimer.start(); // Düzenli güncellemeyi başlat
        }
    }

    // 30 Dakikada bir yenile (1800000 ms)
    Timer {
        id: updateTimer
        interval: 1800000
        running: false // Başlangıçta kapalı, initTimer başlatacak
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            console.log("Hava durumu yenileniyor... (Aralık: " + interval + "ms)");
            apiProc.running = false; // Önce durdur
            apiProc.fullOutput = ""; // Tamponu temizle
            apiProc.running = true;  // Yeniden başlat
        }
    }

    // OpenWeatherMap İkon Eşleştirmesi (Nerd Fonts)
    function getWeatherInfo(code) {
        // Code örneği: "01d", "04n" vs.
        var mapping = {
            "01d": "󰖙", "01n": "󰖔", // Clear
            "02d": "󰖕", "02n": "󰼾", // Few clouds
            "03d": "󰖐", "03n": "󰖐", // Scattered clouds
            "04d": "󰖑", "04n": "󰖑", // Broken clouds
            "09d": "󰖖", "09n": "󰖖", // Shower rain
            "10d": "󰖗", "10n": "󰖗", // Rain
            "11d": "󰖓", "11n": "󰖓", // Thunderstorm
            "13d": "󰖘", "13n": "󰖘", // Snow
            "50d": "󰖑", "50n": "󰖑"  // Mist
        };
        
        var textMapping = {
            "01d": "Clear", "01n": "Clear",
            "02d": "Few Clouds", "02n": "Few Clouds",
            "03d": "Scattered Clouds", "03n": "Scattered Clouds",
            "04d": "Clouds", "04n": "Clouds",
            "09d": "Shower Rain", "09n": "Shower Rain",
            "10d": "Rain", "10n": "Rain",
            "11d": "Thunderstorm", "11n": "Thunderstorm",
            "13d": "Snow", "13n": "Snow",
            "50d": "Mist", "50n": "Mist"
        };
        
        return { icon: mapping[code] || "󰖕", text: textMapping[code] || "Unknown" };
    }
}
