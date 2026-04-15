import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Services/core" as Core
import "../../../Services/core/Log.js" as Log

Item {
    id: service
    visible: false
    width: 0
    height: 0

    readonly property string configPath: Core.PathService.configPath("weather_config.json")
    readonly property string envApiKey: Quickshell.env("OPENWEATHER_API_KEY") || ""

    property bool weatherEnabled: true
    property bool useFahrenheit: false
    property bool autoLocation: false
    property string customLat: "39.9208"
    property string customLon: "41.2746"
    property string cityName: "Erzurum"
    property string apiKey: envApiKey
    property string searchText: ""
    property var searchResults: []
    property bool searching: false

    function saveConfig() {
        var cfg = {
            enabled: weatherEnabled,
            fahrenheit: useFahrenheit,
            autoLocation: autoLocation,
            lat: customLat,
            lon: customLon,
            city: cityName,
            apiKey: apiKey
        };
        configStore.save(cfg);
    }

    function searchCity() {
        var query = searchText.trim();
        if (query === "") return;
        searching = true;
        searchResults = [];
        geoSearchProc.query = encodeURIComponent(query);
        geoSearchProc.buf = "";
        geoSearchProc.running = false;
        geoSearchProc.running = true;
    }

    function toggleAutoLocation() {
        autoLocation = !autoLocation;
        if (autoLocation) {
            autoLocProc.buf = "";
            autoLocProc.running = true;
        }
        saveConfig();
    }

    function selectSearchResult(result) {
        customLat = result.lat;
        customLon = result.lon;
        cityName = result.name.split(",")[0].trim();
        searchResults = [];
        searchText = "";
        saveConfig();
    }

    Process {
        id: geoSearchProc
        property string buf: ""
        property string query: ""
        // Open-Meteo Geocoding API — ücretsiz, API key yok
        command: ["curl", "-s",
            "https://geocoding-api.open-meteo.com/v1/search?name=" + query + "&count=5&language=en&format=json"]
        stdout: SplitParser { onRead: data => geoSearchProc.buf += data }
        onExited: {
            service.searching = false;
            try {
                var json = JSON.parse(geoSearchProc.buf);
                var list = [];
                var results = json.results || [];
                for (var i = 0; i < results.length; i++) {
                    var item = results[i];
                    var label = item.name;
                    if (item.admin1) label += ", " + item.admin1;
                    if (item.country) label += ", " + item.country;
                    list.push({
                        name: label,
                        lat: Number(item.latitude).toFixed(4),
                        lon: Number(item.longitude).toFixed(4)
                    });
                }
                service.searchResults = list;
            } catch (e) {
                Log.warn("WeatherSettingsService", "Search parse error: " + e);
                service.searchResults = [];
            }
            geoSearchProc.buf = "";
        }
    }

    Process {
        id: autoLocProc
        property string buf: ""
        command: ["curl", "-s", "https://ipapi.co/json/"]
        stdout: SplitParser { onRead: data => autoLocProc.buf += data }
        onExited: {
            try {
                var result = JSON.parse(autoLocProc.buf);
                if (result.latitude) service.customLat = Number(result.latitude).toFixed(4);
                if (result.longitude) service.customLon = Number(result.longitude).toFixed(4);
                if (result.city) service.cityName = result.city;
                saveConfig();
            } catch (e) {
                Log.warn("WeatherSettingsService", "Auto location parse error: " + e);
            }
            autoLocProc.buf = "";
        }
    }

    Component.onCompleted: configStore.load()

    Core.JsonDataStore {
        id: configStore
        path: service.configPath
        schemaVersion: 1
        defaultValue: ({
            enabled: true,
            fahrenheit: false,
            autoLocation: false,
            lat: "39.9208",
            lon: "41.2746",
            city: "Erzurum",
            apiKey: ""
        })
        function validate(data) {
            if (typeof data.enabled !== "boolean") data.enabled = !!data.enabled;
            if (typeof data.fahrenheit !== "boolean") data.fahrenheit = !!data.fahrenheit;
            if (typeof data.autoLocation !== "boolean") data.autoLocation = !!data.autoLocation;
            if (typeof data.lat !== "string") data.lat = String(data.lat || "39.9208");
            if (typeof data.lon !== "string") data.lon = String(data.lon || "41.2746");
            return data;
        }
        onLoadedValue: function(cfg) {
            if (cfg.enabled !== undefined) service.weatherEnabled = cfg.enabled;
            if (cfg.fahrenheit !== undefined) service.useFahrenheit = cfg.fahrenheit;
            if (cfg.autoLocation !== undefined) service.autoLocation = cfg.autoLocation;
            if (cfg.lat) service.customLat = cfg.lat;
            if (cfg.lon) service.customLon = cfg.lon;
            if (cfg.city) service.cityName = cfg.city;
            service.apiKey = service.envApiKey.length > 0 ? service.envApiKey : String(cfg.apiKey || "");
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("WeatherSettingsService", "Config parse error: " + details);
        }
    }
}
