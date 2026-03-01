pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.platform

Singleton {
    id: root

    property var screenPreferences: ({})
    property string configPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/screen_config.json"

    // Read config on startup
    Component.onCompleted: {
        readConfigProc.running = true;
    }

    // Periodic re-read for hot-reload
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            readConfigProc.output = "";
            readConfigProc.running = false;
            readConfigProc.running = true;
        }
    }

    Process {
        id: readConfigProc
        command: ["cat", root.configPath]
        property string output: ""
        stdout: SplitParser {
            onRead: data => { readConfigProc.output += data; }
        }
        onExited: {
            if (readConfigProc.output.trim() === "") return;
            try {
                var cfg = JSON.parse(readConfigProc.output);
                root.screenPreferences = cfg;
            } catch(e) {
                console.log("[ScreenManager] Config parse error: " + e);
            }
            readConfigProc.output = "";
        }
    }

    // Save config
    Process {
        id: writeConfigProc
        property string jsonData: ""
        command: ["bash", "-c", "cat > " + root.configPath + " << 'ENDOFJSON'\n" + jsonData + "\nENDOFJSON"]
    }

    function saveConfig() {
        writeConfigProc.jsonData = JSON.stringify(root.screenPreferences, null, 2);
        writeConfigProc.running = false;
        writeConfigProc.running = true;
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
}
