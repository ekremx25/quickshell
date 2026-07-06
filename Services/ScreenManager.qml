pragma Singleton
import QtQuick
import Quickshell
import Qt.labs.platform
import "./core" as Core
import "./core/Log.js" as Log

Singleton {
    id: root

    property var screenPreferences: ({})
    readonly property string configDir: StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell"
    property string configPath: configDir + "/screen_config.json"

    Component.onCompleted: configStore.load()

    function saveConfig() {
        configStore.save(root.screenPreferences);
    }

    function getFilteredScreens(componentId) {
        var prefs = root.screenPreferences[componentId];
        if (!prefs || !Array.isArray(prefs) || prefs.length === 0 || prefs.indexOf("all") !== -1) {
            return Quickshell.screens;
        }
        if (prefs.indexOf("none") !== -1 || prefs[0] === "none") {
            return [];
        }
        return Quickshell.screens.filter(function(screen) {
            return prefs.indexOf(screen.name) !== -1;
        });
    }

    // Set preference for a component
    function setScreenPreference(componentId, screenNames) {
        var prefs = JSON.parse(JSON.stringify(root.screenPreferences));
        prefs[componentId] = screenNames;
        root.screenPreferences = prefs;
        saveConfig();
    }

    // Get list of all connected screen names
    function getAvailableScreenNames() {
        var names = [];
        for (var i = 0; i < Quickshell.screens.length; i++) {
            names.push(Quickshell.screens[i].name);
        }
        return names;
    }

    Core.JsonDataStore {
        id: configStore
        path: root.configPath
        defaultValue: ({})
        onLoadedValue: function(value) {
            root.screenPreferences = value || {};
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("ScreenManager", "Config parse error: " + details);
        }
    }

    Core.FileChangeWatcher {
        path: root.configPath
        interval: 2000
        onChanged: configStore.load()
    }
}
