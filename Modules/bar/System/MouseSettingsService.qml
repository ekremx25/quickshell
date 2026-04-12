import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.platform
import "../../../Services"
import "../../../Services/core" as Core
import "../../../Services/core/Log.js" as Log

Item {
    id: service

    visible: false
    width: 0
    height: 0

    readonly property bool supported: CompositorService.isHyprland
    readonly property string homePath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "")
    readonly property string hyprGeneralConfigPath: homePath + "/.config/hypr/custom/general.conf"
    readonly property string configPath: homePath + "/.config/quickshell/mouse_config.json"

    property real sensitivity: 0.0
    property real scrollFactor: 1.0
    property string accelProfile: "adaptive"
    property string cursorTheme: Quickshell.env("XCURSOR_THEME") || "Adwaita"
    property int cursorSize: parseInt(Quickshell.env("XCURSOR_SIZE") || "24")
    property var availableCursorThemes: []
    property bool isBusy: false
    property string statusMessage: ""
    property bool managedByQuickshell: false

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value))
    }

    function isSaneCursorTheme(theme) {
        var name = String(theme || "").trim()
        if (name.length === 0 || name.length > 96) return false
        var cursorTokenCount = (name.match(/cursors/g) || []).length
        return cursorTokenCount <= 1
    }

    function normalizedCursorTheme(theme) {
        var name = String(theme || "").trim()
        if (!isSaneCursorTheme(name)) {
            return Quickshell.env("XCURSOR_THEME") || "Adwaita"
        }
        return name
    }

    function applySnapshot(cfg) {
        var parsedSensitivity = parseFloat(cfg.sensitivity !== undefined ? cfg.sensitivity : 0.0)
        var parsedScrollFactor = parseFloat(cfg.scrollFactor !== undefined ? cfg.scrollFactor : 1.0)
        var parsedCursorSize = parseInt(cfg.cursorSize !== undefined ? cfg.cursorSize : cursorSize)
        sensitivity = isNaN(parsedSensitivity) ? 0.0 : clamp(parsedSensitivity, -1.0, 1.0)
        scrollFactor = isNaN(parsedScrollFactor) ? 1.0 : clamp(parsedScrollFactor, 0.1, 5.0)
        accelProfile = cfg.accelProfile || "adaptive"
        cursorTheme = normalizedCursorTheme(cfg.cursorTheme || cursorTheme)
        cursorSize = isNaN(parsedCursorSize) ? 24 : Math.max(16, Math.min(64, parsedCursorSize))
        managedByQuickshell = cfg.managedByQuickshell === true
    }

    function loadSettings() {
        if (configStore.loadProcRunning) return
        configStore.loadProcRunning = true
        configStore.load()
    }

    function saveSettings() {
        configStore.save({
            sensitivity: sensitivity,
            scrollFactor: scrollFactor,
            accelProfile: accelProfile,
            cursorTheme: cursorTheme,
            cursorSize: cursorSize,
            managedByQuickshell: true
        })
    }

    function applySettings() {
        if (!supported || isBusy) return
        isBusy = true
        statusMessage = "Applying mouse settings..."
        saveSettings()
    }

    function setAccelProfile(profile) {
        accelProfile = profile
    }

    function setCursorTheme(theme) {
        if (!theme || theme === "") return
        cursorTheme = normalizedCursorTheme(theme)
    }

    function applyRuntimeSettings() {
        if (!supported || runtimeApplyProc.running) return
        runtimeApplyProc.running = true
    }

    function loadAvailableCursorThemes() {
        if (themeScanProc.running) return
        themeScanProc.output = ""
        themeScanProc.running = true
    }

    Component.onCompleted: {
        loadSettings()
        loadAvailableCursorThemes()
    }

    Process {
        id: legacyReadProc
        command: [
            "sh",
            "-c",
            "awk '" +
            "BEGIN { in_input = 0; sens = \"\"; scroll = \"\"; accel = \"\" } " +
            "/^[[:space:]]*input[[:space:]]*\\{/ { in_input = 1; next } " +
            "in_input && /^[[:space:]]*\\}/ { in_input = 0 } " +
            "in_input && $1 == \"sensitivity\" { sens = $3 } " +
            "in_input && $1 == \"scroll_factor\" { scroll = $3 } " +
            "in_input && $1 == \"accel_profile\" { accel = $3 } " +
            "END { " +
            "if (sens == \"\") sens = \"0.0\"; " +
            "if (scroll == \"\") scroll = \"1.0\"; " +
            "if (accel == \"\") accel = \"adaptive\"; " +
            "printf \"{\\\"sensitivity\\\":%s,\\\"scrollFactor\\\":%s,\\\"accelProfile\\\":\\\"%s\\\",\\\"cursorTheme\\\":\\\"%s\\\",\\\"cursorSize\\\":%s,\\\"managedByQuickshell\\\":false}\\n\", sens, scroll, accel, ENVIRON[\"XCURSOR_THEME\"] ? ENVIRON[\"XCURSOR_THEME\"] : \"Adwaita\", ENVIRON[\"XCURSOR_SIZE\"] ? ENVIRON[\"XCURSOR_SIZE\"] : \"24\"; " +
            "}' '" + service.hyprGeneralConfigPath + "' 2>/dev/null || printf '{\"sensitivity\":0.0,\"scrollFactor\":1.0,\"accelProfile\":\"adaptive\",\"managedByQuickshell\":false}\\n'"
        ]
        property string output: ""
        stdout: SplitParser { onRead: data => legacyReadProc.output += data }
        onExited: {
            try {
                var fallbackConfig = JSON.parse(legacyReadProc.output.trim())
                service.applySnapshot(fallbackConfig)
                service.statusMessage = "Loaded defaults from Hyprland"
            } catch (e) {
                Log.warn("MouseSettingsService", "Legacy config parse error: " + e)
            }
            legacyReadProc.output = ""
        }
    }

    Core.JsonDataStore {
        id: configStore
        property bool loadProcRunning: false
        path: service.configPath
        defaultValue: ({
            sensitivity: 0.0,
            scrollFactor: 1.0,
            accelProfile: "adaptive",
            cursorTheme: Quickshell.env("XCURSOR_THEME") || "Adwaita",
            cursorSize: parseInt(Quickshell.env("XCURSOR_SIZE") || "24"),
            managedByQuickshell: false
        })
        onLoadedValue: function(cfg, rawText) {
            loadProcRunning = false
            if (String(rawText || "").trim().length === 0) {
                legacyReadProc.output = ""
                legacyReadProc.running = true
                return
            }
            service.applySnapshot(cfg)
        }
        onSavedValue: function(cfg) {
            service.applySnapshot(cfg)
            service.applyRuntimeSettings()
        }
        onFailed: function(phase, exitCode, details) {
            loadProcRunning = false
            if (phase === "parse") {
                Log.warn("MouseSettingsService", "Config parse error: " + details)
                legacyReadProc.output = ""
                legacyReadProc.running = true
            } else {
                service.isBusy = false
                service.statusMessage = "Failed to save mouse settings"
                Log.warn("MouseSettingsService", "Config " + phase + " failed: " + exitCode + " " + details)
            }
        }
    }

    Process {
        id: runtimeApplyProc
        command: [
            "sh",
            "-c",
            "hyprctl keyword input:sensitivity '" + sensitivity.toFixed(2) + "' >/dev/null 2>&1; " +
            "hyprctl keyword input:scroll_factor '" + scrollFactor.toFixed(2) + "' >/dev/null 2>&1; " +
            "hyprctl keyword input:accel_profile '" + accelProfile + "' >/dev/null 2>&1; " +
            "hyprctl setcursor '" + cursorTheme.replace(/'/g, "'\\''") + "' '" + cursorSize + "' >/dev/null 2>&1"
        ]
        onExited: exitCode => {
            service.isBusy = false
            if (exitCode === 0) {
                service.statusMessage = "Applied by Quickshell"
                service.managedByQuickshell = true
            } else {
                service.statusMessage = "Saved, but runtime apply failed"
                Log.warn("MouseSettingsService", "Runtime apply failed with exit code " + exitCode)
            }
        }
    }

    Process {
        id: themeScanProc
        command: [
            "sh",
            "-c",
            "find /usr/share/icons -mindepth 2 -maxdepth 2 -type d -name cursors -printf '%h\\n' 2>/dev/null | xargs -r -n1 basename | sort -u"
        ]
        property string output: ""
        stdout: SplitParser { onRead: data => themeScanProc.output += data + "\n" }
        onExited: {
            var lines = String(themeScanProc.output || "").split("\n")
            var themes = []
            for (var i = 0; i < lines.length; ++i) {
                var name = lines[i].trim()
                if (name.length > 0 && isSaneCursorTheme(name) && themes.indexOf(name) === -1) themes.push(name)
            }
            if (themes.indexOf(service.cursorTheme) === -1 && service.cursorTheme.length > 0) themes.unshift(service.cursorTheme)
            availableCursorThemes = themes
            themeScanProc.output = ""
        }
    }
}
