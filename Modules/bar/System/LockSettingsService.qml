import QtQuick
import Qt.labs.platform
import Quickshell
import Quickshell.Io
import "../../../Services"
import "../../../Services/core" as Core
import "../../../Services/core/Log.js" as Log

Item {
    id: service

    visible: false
    width: 0
    height: 0

    readonly property bool supported: true
    readonly property bool hyprlandActive: CompositorService.isHyprland
    readonly property string homePath: Core.PathService.homePath
    readonly property string lockConfigPath: Core.PathService.configPath("lock_config.json")
    readonly property string hyprLockDir: Core.PathService.configHome + "/hypr/lock"
    readonly property string hyprlockConfigPath: hyprLockDir + "/hyprlock.conf"
    readonly property string hypridleConfigPath: hyprLockDir + "/hypridle.conf"
    readonly property string defaultBackgroundPath: homePath + "/.config/hypr/lock/wallpaper.jpg"
    property bool brightnessctlAvailable: false

    property string backgroundPath: defaultBackgroundPath
    property int dimTimeoutMinutes: 20
    property int lockTimeoutMinutes: 22
    property int screenOffTimeoutMinutes: 25
    property int suspendTimeoutMinutes: 33
    property bool ignoreMediaInhibit: true
    property bool isBusy: false
    property string statusMessage: ""

    function clampMinutes(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, Math.round(value)))
    }

    function normalizePath(path) {
        return Core.PathService.expandHome(path)
    }

    function applySnapshot(cfg) {
        backgroundPath = normalizePath(cfg.backgroundPath || defaultBackgroundPath)
        dimTimeoutMinutes = clampMinutes(cfg.dimTimeoutMinutes !== undefined ? cfg.dimTimeoutMinutes : 20, 1, 240)
        lockTimeoutMinutes = clampMinutes(cfg.lockTimeoutMinutes !== undefined ? cfg.lockTimeoutMinutes : 22, 1, 240)
        screenOffTimeoutMinutes = clampMinutes(cfg.screenOffTimeoutMinutes !== undefined ? cfg.screenOffTimeoutMinutes : 25, 1, 240)
        suspendTimeoutMinutes = clampMinutes(cfg.suspendTimeoutMinutes !== undefined ? cfg.suspendTimeoutMinutes : 33, 1, 480)
        ignoreMediaInhibit = cfg.ignoreMediaInhibit !== undefined ? !!cfg.ignoreMediaInhibit : true
        normalizeTimeouts()
    }

    function normalizeTimeouts() {
        if (screenOffTimeoutMinutes <= lockTimeoutMinutes) screenOffTimeoutMinutes = lockTimeoutMinutes + 1
        if (suspendTimeoutMinutes <= screenOffTimeoutMinutes) suspendTimeoutMinutes = screenOffTimeoutMinutes + 5
    }

    function saveSettings() {
        normalizeTimeouts()
        configStore.save({
            backgroundPath: Core.PathService.compactHome(backgroundPath),
            dimTimeoutMinutes: dimTimeoutMinutes,
            lockTimeoutMinutes: lockTimeoutMinutes,
            screenOffTimeoutMinutes: screenOffTimeoutMinutes,
            suspendTimeoutMinutes: suspendTimeoutMinutes,
            ignoreMediaInhibit: ignoreMediaInhibit
        })
    }

    function hyprlockLaunchCommand() {
        return "pidof hyprlock || hyprlock -c '" + hyprlockConfigPath.replace(/'/g, "'\\''") + "'"
    }

    function dimScreenTimeoutBlock() {
        if (!brightnessctlAvailable) return ""
        return "listener {\n" +
               "    timeout = " + (dimTimeoutMinutes * 60) + "\n" +
               "    on-timeout = brightnessctl set $(( $(brightnessctl g) / 2 ))\n" +
               "    on-resume = brightnessctl set $(( $(brightnessctl g) * 2 ))\n" +
               "}\n\n"
    }

    function hyprlockText() {
        var bg = backgroundPath.length > 0 ? backgroundPath : defaultBackgroundPath
        return "# Managed by Quickshell\n" +
               "general {\n" +
               "    disable_loading_bar = false\n" +
               "}\n\n" +
               "background {\n" +
               "    path = " + bg + "\n" +
               "}\n\n" +
               "input-field {\n" +
               "    monitor =\n" +
               "    size = 200, 50\n" +
               "    outline_thickness = 3\n" +
               "    rounding = -1\n" +
               "    fade_on_empty = true\n" +
               "    placeholder_text = <span foreground=\"##cba6f7\">Enter Password</span>\n" +
               "    font_size = 24\n" +
               "    shadow_passes = 0\n" +
               "    halign = center\n" +
               "    valign = center\n" +
               "}\n\n" +
               "label {\n" +
               "    monitor =\n" +
               "    text = <span foreground=\"##ffffff\" size=\"xx-large\">SCREEN LOCKED</span>\n" +
               "    font_size = 30\n" +
               "    halign = center\n" +
               "    valign = top\n" +
               "    text_align = center\n" +
               "    pos = 0, 100\n" +
               "}\n"
    }

    function hypridleText() {
        return "# Managed by Quickshell\n" +
               "general {\n" +
               "    lock_cmd = " + hyprlockLaunchCommand() + "\n" +
               "    unlock_cmd = killall hyprlock\n" +
               "    before_sleep_cmd = " + hyprlockLaunchCommand() + "\n" +
               "    after_sleep_cmd = hyprctl dispatch dpms on\n" +
               "    ignore_dbus_inhibit = true\n" +
               "    ignore_systemd_inhibit = true\n" +
               "}\n\n" +
               dimScreenTimeoutBlock() +
               "listener {\n" +
               "    timeout = " + (lockTimeoutMinutes * 60) + "\n" +
               "    on-timeout = " + hyprlockLaunchCommand() + "\n" +
               "    ignore_inhibit = " + (ignoreMediaInhibit ? "true" : "false") + "\n" +
               "}\n\n" +
               "listener {\n" +
               "    timeout = " + (screenOffTimeoutMinutes * 60) + "\n" +
               "    on-timeout = hyprctl dispatch dpms off\n" +
               "    on-resume = hyprctl dispatch dpms on\n" +
               "}\n\n" +
               "listener {\n" +
               "    timeout = " + (suspendTimeoutMinutes * 60) + "\n" +
               "    on-timeout = systemctl suspend\n" +
               "}\n"
    }

    function applySettings() {
        if (isBusy) return
        isBusy = true
        statusMessage = "Applying lock settings..."
        saveSettings()
    }

    function lockNow() {
        if (hyprlandActive) {
            Quickshell.execDetached(["/bin/bash", "-lc", hyprlockLaunchCommand()])
        } else {
            Quickshell.execDetached(["/usr/bin/loginctl", "lock-session"])
        }
    }

    function reloadIdle() {
        if (reloadProc.running) return
        if (!hyprlandActive) {
            statusMessage = "Saved for next Hyprland session"
            return
        }
        reloadProc.running = true
    }

    function loadLegacyConfigs() {
        if (legacyLoadProc.running) return
        legacyLoadProc.output = ""
        legacyLoadProc.running = true
    }

    Component.onCompleted: configStore.load()

    Core.JsonDataStore {
        id: configStore
        path: service.lockConfigPath
        defaultValue: ({
            backgroundPath: service.defaultBackgroundPath,
            dimTimeoutMinutes: 20,
            lockTimeoutMinutes: 22,
            screenOffTimeoutMinutes: 25,
            suspendTimeoutMinutes: 33,
            ignoreMediaInhibit: true
        })
        onLoadedValue: function(cfg, rawText) {
            if (String(rawText || "").trim().length === 0) {
                service.loadLegacyConfigs()
                return
            }
            service.applySnapshot(cfg)
        }
        onSavedValue: function(cfg) {
            service.applySnapshot(cfg)
            hyprlockStore.write(service.hyprlockText())
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") {
                service.loadLegacyConfigs()
            } else {
                service.isBusy = false
                service.statusMessage = "Failed to save lock settings"
                Log.warn("LockSettingsService", "Config " + phase + " failed: " + exitCode + " " + details)
            }
        }
    }

    Process {
        id: brightnessctlCheckProc
        command: ["bash", "-lc", "command -v brightnessctl >/dev/null 2>&1"]
        running: true
        onExited: function(exitCode) {
            service.brightnessctlAvailable = exitCode === 0
        }
    }

    Core.TextDataStore {
        id: hyprlockStore
        path: service.hyprlockConfigPath
        onSaved: hypridleStore.write(service.hypridleText())
        onFailed: function(phase, exitCode, details) {
            service.isBusy = false
            service.statusMessage = "Failed to write hyprlock.conf"
            Log.warn("LockSettingsService", "hyprlock write failed: " + phase + " " + exitCode + " " + details)
        }
    }

    Core.TextDataStore {
        id: hypridleStore
        path: service.hypridleConfigPath
        onSaved: {
            if (service.hyprlandActive) {
                reloadProc.running = true
            } else {
                service.isBusy = false
                service.statusMessage = "Saved for next Hyprland session"
            }
        }
        onFailed: function(phase, exitCode, details) {
            service.isBusy = false
            service.statusMessage = "Failed to write hypridle.conf"
            Log.warn("LockSettingsService", "hypridle write failed: " + phase + " " + exitCode + " " + details)
        }
    }

    Process {
        id: reloadProc
        command: [
            "/bin/bash",
            "-lc",
            "pkill hypridle >/dev/null 2>&1 || true; " +
            "hyprctl dispatch exec \"hypridle -c " + service.hypridleConfigPath.replace(/"/g, "\\\"") + "\""
        ]
        running: false
        onExited: function(exitCode) {
            service.isBusy = false
            service.statusMessage = exitCode === 0 ? "Applied by Quickshell" : "Saved, but live reload failed"
            if (exitCode !== 0) Log.warn("LockSettingsService", "hypridle reload failed with exit code " + exitCode)
        }
    }

    Process {
        id: legacyLoadProc
        command: [
            "bash",
            "-lc",
            "BG=$(sed -n 's/^[[:space:]]*path = //p' " + "'" + service.hyprlockConfigPath.replace(/'/g, "'\\''") + "'" + " 2>/dev/null | head -n1); " +
            "awk 'BEGIN { RS=\"listener[[:space:]]*\\\\{\"; FS=\"\\n\"; dim=1200; lock=1320; off=1500; suspend=1980; ignore=\"true\" } " +
            "NR > 1 { timeout=\"\"; onTimeout=\"\"; ignoreValue=\"\"; " +
            "for (i = 1; i <= NF; ++i) { line=$i; gsub(/^[[:space:]]+|[[:space:]]+$/, \"\", line); " +
            "if (line ~ /^timeout = /) { sub(/^timeout = /, \"\", line); timeout=line } " +
            "else if (line ~ /^on-timeout = /) { sub(/^on-timeout = /, \"\", line); onTimeout=line } " +
            "else if (line ~ /^ignore_inhibit = /) { sub(/^ignore_inhibit = /, \"\", line); ignoreValue=line } } " +
            "if (onTimeout ~ /^brightnessctl /) dim=timeout; " +
            "else if (onTimeout ~ /^hyprctl dispatch dpms off$/) off=timeout; " +
            "else if (onTimeout ~ /^systemctl suspend$/) suspend=timeout; " +
            "else if (onTimeout ~ /hyprlock/ || onTimeout ~ /^loginctl lock-session$/) { lock=timeout; if (ignoreValue != \"\") ignore=ignoreValue } } " +
            "END { printf \"{\\\"dimTimeoutMinutes\\\":%d,\\\"lockTimeoutMinutes\\\":%d,\\\"screenOffTimeoutMinutes\\\":%d,\\\"suspendTimeoutMinutes\\\":%d,\\\"ignoreMediaInhibit\\\":%s}\\n\", dim / 60, lock / 60, off / 60, suspend / 60, ignore }' " +
            "'" + service.hypridleConfigPath.replace(/'/g, "'\\''") + "'" +
            " | { read -r JSON || JSON='{}'; printf '{\"backgroundPath\":\"%s\",%s\\n' \"$BG\" \"${JSON#\\{}\"; }"
        ]
        running: false
        property string output: ""
        stdout: SplitParser { onRead: data => legacyLoadProc.output += data }
        onExited: {
            try {
                service.applySnapshot(JSON.parse(legacyLoadProc.output.trim()))
                service.statusMessage = "Loaded from existing Hyprlock config"
            } catch (e) {
                service.applySnapshot(configStore.defaultValue)
                Log.warn("LockSettingsService", "Legacy config parse error: " + e)
            }
            legacyLoadProc.output = ""
        }
    }
}
