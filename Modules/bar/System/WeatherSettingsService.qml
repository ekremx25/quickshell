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
    property bool worldClockEnabled: true
    property var worldClocks: defaultWorldClocks()
    property string worldClockStatus: ""
    property var countries: []
    property string selectedCountryCode: ""
    property string selectedCountryName: ""

    function defaultWorldClocks() {
        return [
            { id: "zurich-ch", city: "Zurich", country: "Switzerland", timezone: "Europe/Zurich", lat: "47.3769", lon: "8.5417" },
            { id: "tokyo-jp", city: "Tokyo", country: "Japan", timezone: "Asia/Tokyo", lat: "35.6762", lon: "139.6503" },
            { id: "sydney-au", city: "Sydney", country: "Australia", timezone: "Australia/Sydney", lat: "-33.8688", lon: "151.2093" },
            { id: "paris-fr", city: "Paris", country: "France", timezone: "Europe/Paris", lat: "48.8566", lon: "2.3522" }
        ];
    }

    function saveConfig() {
        var cfg = {
            enabled: weatherEnabled,
            fahrenheit: useFahrenheit,
            autoLocation: autoLocation,
            lat: customLat,
            lon: customLon,
            city: cityName,
            apiKey: apiKey,
            worldClockEnabled: worldClockEnabled,
            worldClocks: worldClocks,
            _schemaVersion: 2
        };
        configStore.save(cfg);
    }

    function searchCity() {
        var query = searchText.trim();
        if (query === "") return;
        searching = true;
        searchResults = [];
        geoSearchProc.query = encodeURIComponent(query);
        geoSearchProc.countryCode = selectedCountryCode;
        geoSearchProc.buf = "";
        geoSearchProc.running = false;
        geoSearchProc.running = true;
    }

    function selectCountry(country) {
        selectedCountryCode = String(country.code || "");
        selectedCountryName = String(country.name || "");
        searchText = "";
        searchResults = [];
        worldClockStatus = "";
    }

    function filterCountries(query) {
        var needle = String(query || "").trim().toLocaleLowerCase();
        if (needle.length === 0) return countries;
        return countries.filter(function(country) {
            return country.name.toLocaleLowerCase().indexOf(needle) !== -1
                    || country.code.toLocaleLowerCase().indexOf(needle) === 0;
        });
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
        cityName = result.city;
        searchResults = [];
        searchText = "";
        saveConfig();
    }

    function canAddWorldClock(result) {
        if (!result || worldClocks.length >= 8) return false;
        for (var i = 0; i < worldClocks.length; i++) {
            if (worldClocks[i].id === result.id) return false;
        }
        return true;
    }

    function addWorldClock(result) {
        if (!canAddWorldClock(result)) {
            worldClockStatus = worldClocks.length >= 8
                    ? "A maximum of 8 cities can be displayed."
                    : "This city is already on the desktop.";
            return;
        }
        var next = worldClocks.slice();
        next.push({
            id: result.id,
            city: result.city,
            country: result.country,
            timezone: result.timezone,
            lat: result.lat,
            lon: result.lon
        });
        worldClocks = next;
        worldClockStatus = result.city + " added to the desktop.";
        saveConfig();
    }

    function removeWorldClock(index) {
        if (index < 0 || index >= worldClocks.length) return;
        var next = worldClocks.slice();
        var removed = next.splice(index, 1)[0];
        worldClocks = next;
        worldClockStatus = removed.city + " removed.";
        saveConfig();
    }

    function moveWorldClock(index, direction) {
        var target = index + direction;
        if (index < 0 || target < 0 || index >= worldClocks.length || target >= worldClocks.length) return;
        var next = worldClocks.slice();
        var item = next[index];
        next[index] = next[target];
        next[target] = item;
        worldClocks = next;
        saveConfig();
    }

    Process {
        id: geoSearchProc
        property string buf: ""
        property string query: ""
        property string countryCode: ""
        // Open-Meteo Geocoding API — free, no API key
        command: ["curl", "-fsS", "--max-time", "15",
            "https://geocoding-api.open-meteo.com/v1/search?name=" + query
                + "&count=20&language=en&format=json"
                + (countryCode.length > 0 ? "&countryCode=" + encodeURIComponent(countryCode) : "")]
        stdout: SplitParser { onRead: data => geoSearchProc.buf += data }
        stderr: SplitParser { onRead: data => Log.warn("WeatherSettingsService", "Geocoding curl: " + data) }
        onExited: function(exitCode) {
            service.searching = false;
            try {
                var json = JSON.parse(geoSearchProc.buf);
                var list = [];
                var results = json.results || [];
                for (var i = 0; i < results.length; i++) {
                    var item = results[i];
                    if (geoSearchProc.countryCode.length > 0
                            && String(item.country_code || "").toUpperCase() !== geoSearchProc.countryCode.toUpperCase()) continue;
                    var label = item.name;
                    if (item.admin1) label += ", " + item.admin1;
                    if (item.country) label += ", " + item.country;
                    list.push({
                        id: String(item.id || (Number(item.latitude).toFixed(4) + ":" + Number(item.longitude).toFixed(4))),
                        name: label,
                        city: String(item.name || label),
                        country: String(item.country || ""),
                        countryCode: String(item.country_code || ""),
                        timezone: String(item.timezone || "auto"),
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
        id: countryListProc
        command: ["cat", Core.PathService.configPath("assets/countries.json")]
        running: true
        property string output: ""
        stdout: SplitParser { onRead: data => countryListProc.output += data }
        onExited: {
            try {
                var list = JSON.parse(output);
                list.sort(function(a, b) { return a.name.localeCompare(b.name); });
                service.countries = list;
            } catch (e) {
                Log.warn("WeatherSettingsService", "Country list parse error: " + e);
                service.countries = [];
            }
            output = "";
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
        schemaVersion: 2
        defaultValue: ({
            enabled: true,
            fahrenheit: false,
            autoLocation: false,
            lat: "39.9208",
            lon: "41.2746",
            city: "Erzurum",
            apiKey: "",
            worldClockEnabled: true,
            worldClocks: service.defaultWorldClocks(),
            _schemaVersion: 2
        })
        function migrate(data, fromVersion) {
            if (fromVersion < 2) {
                if (typeof data.worldClockEnabled !== "boolean") data.worldClockEnabled = true;
                if (!Array.isArray(data.worldClocks)) data.worldClocks = service.defaultWorldClocks();
            }
            return data;
        }
        function validate(data) {
            if (typeof data.enabled !== "boolean") data.enabled = !!data.enabled;
            if (typeof data.fahrenheit !== "boolean") data.fahrenheit = !!data.fahrenheit;
            if (typeof data.autoLocation !== "boolean") data.autoLocation = !!data.autoLocation;
            if (typeof data.lat !== "string") data.lat = String(data.lat || "39.9208");
            if (typeof data.lon !== "string") data.lon = String(data.lon || "41.2746");
            if (typeof data.worldClockEnabled !== "boolean") data.worldClockEnabled = true;
            if (!Array.isArray(data.worldClocks)) data.worldClocks = service.defaultWorldClocks();
            data.worldClocks = data.worldClocks.slice(0, 8).filter(function(item) {
                return item && item.city && item.lat !== undefined && item.lon !== undefined;
            });
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
            if (cfg.worldClockEnabled !== undefined) service.worldClockEnabled = cfg.worldClockEnabled;
            service.worldClocks = Array.isArray(cfg.worldClocks) ? cfg.worldClocks : service.defaultWorldClocks();
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("WeatherSettingsService", "Config parse error: " + details);
        }
    }

    Core.FileChangeWatcher {
        path: service.configPath
        interval: 1000
        onChanged: configStore.load()
    }
}
