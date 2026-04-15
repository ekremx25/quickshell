pragma Singleton

import QtQuick
import Quickshell
import Qt.labs.platform

QtObject {
    id: root

    function stripFileScheme(path) {
        return String(path || "").replace("file://", "")
    }

    readonly property string homePath: stripFileScheme(StandardPaths.writableLocation(StandardPaths.HomeLocation).toString())
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || stripFileScheme(StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString())
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (homePath + "/.local/state")
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || stripFileScheme(StandardPaths.writableLocation(StandardPaths.CacheLocation).toString())
    readonly property string runtimeHome: Quickshell.env("XDG_RUNTIME_DIR") || stripFileScheme(StandardPaths.writableLocation(StandardPaths.RuntimeLocation).toString())

    readonly property string quickshellConfigDir: configHome + "/quickshell"
    readonly property string quickshellStateDir: stateHome + "/quickshell"
    readonly property string quickshellCacheDir: cacheHome + "/quickshell"
    readonly property string quickshellRuntimeDir: runtimeHome + "/quickshell"

    function configPath(relativePath) {
        return quickshellConfigDir + "/" + String(relativePath || "")
    }

    function statePath(relativePath) {
        return quickshellStateDir + "/" + String(relativePath || "")
    }

    function cachePath(relativePath) {
        return quickshellCacheDir + "/" + String(relativePath || "")
    }

    function runtimePath(relativePath) {
        return quickshellRuntimeDir + "/" + String(relativePath || "")
    }

    function expandHome(path) {
        var value = String(path || "").trim()
        if (value === "~") return homePath
        if (value.indexOf("~/") === 0) return homePath + value.substring(1)
        return value
    }

    function compactHome(path) {
        var value = String(path || "").trim()
        if (value === homePath) return "~"
        if (value.indexOf(homePath + "/") === 0) return "~" + value.substring(homePath.length)
        return value
    }
}
