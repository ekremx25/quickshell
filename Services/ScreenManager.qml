pragma Singleton
import QtQuick
import Quickshell
import Qt.labs.platform
import "./core" as Core
import "./core/Log.js" as Log

Singleton {
    id: root

    property var screenPreferences: ({})
    property var runtimeRoleMap: ({})
    readonly property string configDir: StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell"
    property string configPath: configDir + "/screen_config.json"
    property string runtimePath: configDir + "/monitor_runtime.json"

    Component.onCompleted: {
        configStore.load();
        runtimeStore.load();
    }

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
        var resolvedNames = prefs.map(function(value) {
            return root.runtimeRoleMap[value] || value;
        });
        return Quickshell.screens.filter(function(screen) {
            return resolvedNames.indexOf(screen.name) !== -1;
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
        var roles = ["primary", "secondary", "tertiary"];
        var names = [];
        for (var i = 0; i < roles.length; i++) {
            var connector = root.runtimeRoleMap[roles[i]];
            if (!connector) continue;
            for (var j = 0; j < Quickshell.screens.length; j++) {
                if (Quickshell.screens[j].name === connector) {
                    names.push(roles[i]);
                    break;
                }
            }
        }
        if (names.length === 0) {
            for (var k = 0; k < Quickshell.screens.length; k++) names.push(Quickshell.screens[k].name);
        }
        return names;
    }

    function screenLabel(roleOrName) {
        if (roleOrName === "primary") return "Main";
        if (roleOrName === "secondary") return "Secondary";
        if (roleOrName === "tertiary") return "Third";
        return roleOrName;
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

    Core.JsonDataStore {
        id: runtimeStore
        path: root.runtimePath
        defaultValue: ({})
        onLoadedValue: function(value) {
            root.runtimeRoleMap = value || {};
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("ScreenManager", "Runtime role map parse error: " + details);
        }
    }

    Core.FileChangeWatcher {
        path: root.configPath
        interval: 2000
        onChanged: configStore.load()
    }


    Core.FileChangeWatcher {
        path: root.runtimePath
        interval: 1000
        onChanged: runtimeStore.load()
    }
}
