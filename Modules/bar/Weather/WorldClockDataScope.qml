import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Services/core" as Core
import "../../../Services/core/Log.js" as Log

Scope {
    id: root

    readonly property string configPath: Core.PathService.configPath("weather_config.json")
    readonly property string cachePath: Core.PathService.cachePath("world_clocks.json")
    property bool enabled: true
    property bool useFahrenheit: false
    property var cities: []
    property double clockEpoch: Date.now()

    function defaultCities() {
        return [
            { id: "zurich-ch", city: "Zurich", country: "Switzerland", timezone: "Europe/Zurich", lat: "47.3769", lon: "8.5417" },
            { id: "tokyo-jp", city: "Tokyo", country: "Japan", timezone: "Asia/Tokyo", lat: "35.6762", lon: "139.6503" },
            { id: "sydney-au", city: "Sydney", country: "Australia", timezone: "Australia/Sydney", lat: "-33.8688", lon: "151.2093" },
            { id: "paris-fr", city: "Paris", country: "France", timezone: "Europe/Paris", lat: "48.8566", lon: "2.3522" }
        ];
    }

    function weatherIcon(code, isDay) {
        if (code === 0 || code === 1) return isDay ? "☀" : "☾";
        if (code === 2) return "⛅";
        if (code === 3) return "☁";
        if (code === 45 || code === 48) return "〰";
        if (code >= 51 && code <= 67) return "🌧";
        if (code >= 71 && code <= 77) return "❄";
        if (code >= 80 && code <= 82) return "🌦";
        if (code >= 85 && code <= 86) return "🌨";
        if (code >= 95) return "⛈";
        return "⛅";
    }

    function triggerRefresh() {
        if (!enabled || cities.length === 0 || weatherProc.running) return;
        var latitudes = [];
        var longitudes = [];
        for (var i = 0; i < cities.length; i++) {
            latitudes.push(cities[i].lat);
            longitudes.push(cities[i].lon);
        }
        var unit = useFahrenheit ? "&temperature_unit=fahrenheit" : "";
        var url = "https://api.open-meteo.com/v1/forecast"
                + "?latitude=" + latitudes.join(",")
                + "&longitude=" + longitudes.join(",")
                + "&current=temperature_2m,weather_code,is_day"
                + "&timezone=auto&forecast_days=1" + unit;
        weatherProc.command = ["curl", "-fsS", "--max-time", "15", url];
        weatherProc.output = "";
        weatherProc.running = true;
    }

    function applyWeather(payload) {
        var responses = Array.isArray(payload) ? payload : [payload];
        var next = [];
        for (var i = 0; i < cities.length; i++) {
            var base = cities[i];
            var response = responses[i] || {};
            var current = response.current || {};
            next.push({
                id: base.id,
                city: base.city,
                country: base.country || "",
                timezone: response.timezone || base.timezone || "auto",
                lat: base.lat,
                lon: base.lon,
                utcOffsetSeconds: Number(response.utc_offset_seconds || base.utcOffsetSeconds || 0),
                temperature: current.temperature_2m !== undefined ? Math.round(current.temperature_2m) : (base.temperature !== undefined ? base.temperature : "--"),
                icon: current.weather_code !== undefined ? weatherIcon(Number(current.weather_code), Number(current.is_day) === 1) : (base.icon || "⛅")
            });
        }
        cities = next;
        cacheStore.save({ cities: next, fahrenheit: useFahrenheit, updatedAt: new Date().toISOString() });
    }

    Component.onCompleted: {
        configStore.load();
        cacheStore.load();
    }

    Timer {
        interval: 30000
        running: root.enabled && root.cities.length > 0
        repeat: false
        onTriggered: root.triggerRefresh()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.clockEpoch = Date.now()
    }

    Timer {
        id: refreshTimer
        interval: 1800000
        running: root.enabled
        repeat: true
        onTriggered: root.triggerRefresh()
    }

    Process {
        id: weatherProc
        property string output: ""
        stdout: SplitParser { onRead: data => weatherProc.output += data }
        stderr: SplitParser { onRead: data => Log.warn("WorldClockDataScope", "curl: " + data) }
        onExited: function(exitCode) {
            if (exitCode === 0 && output.trim().length > 0) {
                try {
                    root.applyWeather(JSON.parse(output));
                } catch (e) {
                    Log.warn("WorldClockDataScope", "Weather parse error: " + e);
                }
            }
            output = "";
        }
    }

    Core.JsonDataStore {
        id: configStore
        path: root.configPath
        defaultValue: ({ worldClockEnabled: true, worldClocks: root.defaultCities() })
        onLoadedValue: function(cfg) {
            var configured = Array.isArray(cfg.worldClocks) ? cfg.worldClocks.slice(0, 8) : root.defaultCities();
            root.enabled = cfg.worldClockEnabled !== false;
            root.useFahrenheit = cfg.fahrenheit === true;
            root.cities = configured;
            root.triggerRefresh();
        }
    }

    Core.FileChangeWatcher {
        path: root.configPath
        interval: 1500
        onChanged: configStore.load()
    }

    Core.JsonDataStore {
        id: cacheStore
        path: root.cachePath
        defaultValue: ({ cities: [] })
        onLoadedValue: function(data) {
            if (root.cities.length === 0 || !Array.isArray(data.cities)) return;
            var cacheById = {};
            for (var i = 0; i < data.cities.length; i++) cacheById[data.cities[i].id] = data.cities[i];
            var merged = [];
            for (var j = 0; j < root.cities.length; j++) {
                var current = root.cities[j];
                var cached = cacheById[current.id] || {};
                var copy = {};
                for (var key in cached) copy[key] = cached[key];
                for (var ownKey in current) copy[ownKey] = current[ownKey];
                merged.push(copy);
            }
            root.cities = merged;
        }
    }
}
