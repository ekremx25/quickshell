import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Services/core" as Core
import "../../../Services/core/Log.js" as Log

Scope {
    id: root

    property string currentTemp: "--"
    property string weatherIcon: "󰖕"
    property string cityName: "Erzurum"
    property string customLat: "39.9208"
    property string customLon: "41.2746"
    property string apiKey: ""         // gerekmiyor
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

    property string cachePath: Core.PathService.cachePath("weather.json")
    readonly property string weatherConfigPath: Core.PathService.configPath("weather_config.json")

    function triggerRefresh() {
        if (!root.weatherEnabled) return;
        var tempUnit = root.useFahrenheit ? "&temperature_unit=fahrenheit" : "";
        var windUnit = "&windspeed_unit=kmh";
        var url = "https://api.open-meteo.com/v1/forecast"
                + "?latitude="  + root.customLat
                + "&longitude=" + root.customLon
                + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weathercode,windspeed_10m,is_day"
                + "&daily=weathercode,temperature_2m_max,temperature_2m_min,sunrise,sunset"
                + "&timezone=auto&forecast_days=5"
                + tempUnit + windUnit;
        apiProc.command = ["curl", "-s", url];
        apiProc.running = false;
        apiProc.fullOutput = "";
        apiProc.running = true;
    }

    Component.onCompleted: {
        weatherConfigStore.load();
        cacheStore.load();
    }

    Process {
        id: apiProc
        command: ["curl", "-s", "https://api.open-meteo.com/v1/forecast"]
        property string fullOutput: ""

        stdout: SplitParser { onRead: data => { apiProc.fullOutput += data; } }
        stderr: SplitParser { onRead: data => Log.warn("WeatherDataScope", "curl stderr: " + data) }

        onExited: {
            if (apiProc.fullOutput.trim() === "") {
                Log.warn("WeatherDataScope", "Weather data empty, retrying in 30s");
                cacheStore.load();
                updateTimer.interval = 30000;
                updateTimer.restart();
                return;
            }

            try {
                var json = JSON.parse(apiProc.fullOutput);
                if (json.error) {
                    Log.warn("WeatherDataScope", "Open-Meteo error: " + json.reason);
                    cacheStore.load();
                    updateTimer.interval = 60000;
                    updateTimer.restart();
                    return;
                }

                var cur = json.current;
                var daily = json.daily;

                root.currentTemp = Math.round(cur.temperature_2m).toString();
                root.weatherIcon  = root.getWeatherIcon(cur.weathercode, cur.is_day === 1);

                // Açıklama metni
                var desc = root.getWeatherDesc(cur.weathercode);

                // Sunrise/Sunset (bugün, ISO string → HH:MM)
                function fmtTime(iso) {
                    if (!iso) return "--:--";
                    var d = new Date(iso);
                    var h = d.getHours().toString().padStart(2, "0");
                    var m = d.getMinutes().toString().padStart(2, "0");
                    return h + ":" + m;
                }

                // 5 günlük tahmin
                var dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                var forecastList = [];
                for (var i = 0; i < daily.time.length; i++) {
                    var date = new Date(daily.time[i] + "T12:00:00");
                    var today = new Date();
                    var isToday = (date.getDate()   === today.getDate() &&
                                   date.getMonth()  === today.getMonth() &&
                                   date.getFullYear() === today.getFullYear());
                    forecastList.push({
                        day:  isToday ? "Today" : dayNames[date.getDay()],
                        max:  Math.round(daily.temperature_2m_max[i]),
                        min:  Math.round(daily.temperature_2m_min[i]),
                        icon: root.getWeatherIcon(daily.weathercode[i], true)
                    });
                }

                root.popupData = {
                    desc:      desc,
                    feelsLike: Math.round(cur.apparent_temperature).toString(),
                    humidity:  cur.relative_humidity_2m.toString(),
                    wind:      Math.round(cur.windspeed_10m).toString(),
                    sunrise:   fmtTime(daily.sunrise[0]),
                    sunset:    fmtTime(daily.sunset[0]),
                    forecast:  forecastList
                };

                var cacheData = {
                    currentTemp: root.currentTemp,
                    icon: root.weatherIcon,
                    popupData: root.popupData,
                    lastUpdate: new Date().toLocaleString()
                };
                cacheStore.save(cacheData);

                updateTimer.interval = 1800000;
                updateTimer.restart();
            } catch (e) {
                Log.warn("WeatherDataScope", "Weather JSON error: " + e);
                cacheStore.load();
                updateTimer.interval = 60000;
                updateTimer.restart();
            }
            apiProc.fullOutput = "";
        }
    }

    Timer {
        id: updateTimer
        interval: 1800000  // 30 dakikada bir güncelle
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.triggerRefresh()
    }

    Timer {
        id: initTimer
        interval: 3000
        running: true
        repeat: false
        onTriggered: root.triggerRefresh()
    }

    // WMO Weather Codes → Nerd Font ikonlar
    function getWeatherIcon(code, isDaylight) {
        if (code === 0)  return "☀";                    // Clear sky
        if (code === 1)  return "☀";                    // Mainly clear
        if (code === 2)  return "⛅";                    // Partly cloudy
        if (code === 3)  return "☁";                    // Overcast
        if (code === 45 || code === 48) return "〰";     // Fog
        if (code >= 51 && code <= 55)   return "🌦";     // Drizzle
        if (code >= 56 && code <= 57)   return "🌨";     // Freezing drizzle
        if (code === 61 || code === 63) return "🌧";     // Light/moderate rain
        if (code === 65)                return "🌧";     // Heavy rain
        if (code >= 66 && code <= 67)   return "🌨";     // Freezing rain
        if (code >= 71 && code <= 75)   return "❄";     // Snow
        if (code === 77)                return "❄";     // Snow grains
        if (code === 80 || code === 81) return "🌦";     // Rain showers
        if (code === 82)                return "🌧";     // Heavy rain showers
        if (code >= 85 && code <= 86)   return "🌨";     // Snow showers
        if (code === 95)                return "⛈";     // Thunderstorm
        if (code >= 96 && code <= 99)   return "⛈";     // Thunderstorm w/ hail
        return "⛅";
    }

    // WMO kodundan açıklama
    function getWeatherDesc(code) {
        if (code === 0)  return "Clear Sky";
        if (code === 1)  return "Mainly Clear";
        if (code === 2)  return "Partly Cloudy";
        if (code === 3)  return "Overcast";
        if (code === 45) return "Foggy";
        if (code === 48) return "Icy Fog";
        if (code >= 51 && code <= 53) return "Drizzle";
        if (code === 55) return "Heavy Drizzle";
        if (code >= 56 && code <= 57) return "Freezing Drizzle";
        if (code === 61) return "Light Rain";
        if (code === 63) return "Moderate Rain";
        if (code === 65) return "Heavy Rain";
        if (code >= 66 && code <= 67) return "Freezing Rain";
        if (code === 71) return "Light Snow";
        if (code === 73) return "Moderate Snow";
        if (code === 75) return "Heavy Snow";
        if (code === 77) return "Snow Grains";
        if (code >= 80 && code <= 81) return "Rain Showers";
        if (code === 82) return "Heavy Showers";
        if (code >= 85 && code <= 86) return "Snow Showers";
        if (code === 95) return "Thunderstorm";
        if (code >= 96 && code <= 99) return "Thunderstorm w/ Hail";
        return "Unknown";
    }

    Core.JsonDataStore {
        id: weatherConfigStore
        path: root.weatherConfigPath
        defaultValue: ({
            lat: root.customLat,
            lon: root.customLon,
            city: root.cityName,
            fahrenheit: root.useFahrenheit,
            enabled: root.weatherEnabled
        })
        onLoadedValue: function(cfg) {
            var changed = false;
            if (cfg.lat && cfg.lat !== root.customLat) { root.customLat = cfg.lat; changed = true; }
            if (cfg.lon && cfg.lon !== root.customLon) { root.customLon = cfg.lon; changed = true; }
            if (cfg.city && cfg.city !== root.cityName) { root.cityName = cfg.city; }
            if (cfg.fahrenheit !== undefined && cfg.fahrenheit !== root.useFahrenheit) { root.useFahrenheit = cfg.fahrenheit; changed = true; }
            if (cfg.enabled !== undefined && cfg.enabled !== root.weatherEnabled) { root.weatherEnabled = cfg.enabled; }
            if (changed) {
                root.triggerRefresh();
                updateTimer.restart();
            }
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("WeatherDataScope", "Weather config parse error: " + details);
        }
    }

    Core.FileChangeWatcher {
        path: root.weatherConfigPath
        interval: 1500
        onChanged: weatherConfigStore.load()
    }

    Core.JsonDataStore {
        id: cacheStore
        path: root.cachePath
        defaultValue: ({})
        onLoadedValue: function(json) {
            if (json.currentTemp) root.currentTemp = json.currentTemp;
            if (json.icon) root.weatherIcon = json.icon;
            if (json.popupData) root.popupData = json.popupData;
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("WeatherDataScope", "Weather cache parse error: " + details);
        }
    }
}
