pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services
import "./core" as Core
import "./core/Log.js" as Log

// Blue-light / colour-temperature filter.
//
// Backend selection:
//   - Hyprland  → hyprsunset   (wlr-gamma-control was removed in modern
//                                Hyprland, so gammastep no longer works here)
//   - Niri/Mango → gammastep    (wlr-gamma-control via wlroots)
//
// Apply model (hyprsunset):
//   enabled=true   → `hyprctl hyprsunset temperature <K>` (if daemon running)
//                    otherwise spawn `hyprsunset -t <K>` to start the daemon
//   enabled=false  → `hyprctl hyprsunset identity` + kill daemon
//
// Apply model (gammastep):
//   One owned Wayland process holds the adjustment; stopping it releases it.
//   Temperature changes wait for the previous process to exit before starting.
//
// Schedule:
//   When scheduleEnabled, a 1s Timer flips `enabled` on/off based on the
//   current local time. Windows spanning midnight are supported.
Singleton {
    id: root

    // ── Manual state ─────────────────────────────────────────────────────
    property bool enabled: false
    property int temperature: 4000     // Kelvin
    property bool applyOnStartup: true

    // ── Schedule state ───────────────────────────────────────────────────
    property bool scheduleEnabled: false
    property int scheduleOnHour: 19
    property int scheduleOnMinute: 0
    property int scheduleOffHour: 7
    property int scheduleOffMinute: 0

    readonly property int minTemperature: 1000
    readonly property int maxTemperature: 6500
    readonly property int defaultTemperature: 4000

    // ── Backend ──────────────────────────────────────────────────────────
    property bool available: false
    property string backend: ""        // "hyprsunset" | "gammastep" | ""
    property string errorMessage: ""
    property bool configReady: false
    property bool gammaRestartPending: false

    readonly property string configPath: Core.PathService.configPath("nightlight_config.json")

    Component.onCompleted: {
        // Pick backend based on compositor. Hyprland requires hyprsunset;
        // wlroots compositors (Niri/Mango) can keep using gammastep.
        if (Services.CompositorService.isHyprland) {
            hyprsunsetCheck.running = true;
        } else {
            gammastepCheck.running = true;
        }
        configStore.load();
    }

    // Hyprland path: look for hyprsunset first, fall back to gammastep.
    Process {
        id: hyprsunsetCheck
        command: ["which", "hyprsunset"]
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                root.backend = "hyprsunset";
                root.available = true;
                _reevaluate(true);
            } else {
                gammastepCheck.running = true;
            }
        }
    }

    Process {
        id: gammastepCheck
        command: ["which", "gammastep"]
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                root.backend = "gammastep";
                root.available = true;
                _reevaluate(true);
                return;
            }
            root.available = false;
            root.errorMessage = Services.CompositorService.isHyprland
                ? "hyprsunset is not installed"
                : "gammastep is not installed";
            Log.warn("NightLight", root.errorMessage);
        }
    }

    // ── Public API ───────────────────────────────────────────────────────
    function setEnabled(v) {
        if (root.enabled === v) return;
        root.enabled = v;
        saveConfig();
        _applyNow();
    }

    function setTemperature(k) {
        var clamped = Math.max(root.minTemperature, Math.min(root.maxTemperature, Math.round(k)));
        if (clamped === root.temperature) return;
        root.temperature = clamped;
        saveConfig();
        if (root.enabled) applyDebounce.restart();
    }

    function setApplyOnStartup(v) {
        root.applyOnStartup = v;
        saveConfig();
    }

    function setScheduleEnabled(v) {
        if (root.scheduleEnabled === v) return;
        root.scheduleEnabled = v;
        saveConfig();
        _reevaluate(true);
    }

    function setScheduleOn(h, m) {
        root.scheduleOnHour = Math.max(0, Math.min(23, Math.floor(h)));
        root.scheduleOnMinute = Math.max(0, Math.min(59, Math.floor(m)));
        saveConfig();
        if (root.scheduleEnabled) _reevaluate(true);
    }

    function setScheduleOff(h, m) {
        root.scheduleOffHour = Math.max(0, Math.min(23, Math.floor(h)));
        root.scheduleOffMinute = Math.max(0, Math.min(59, Math.floor(m)));
        saveConfig();
        if (root.scheduleEnabled) _reevaluate(true);
    }

    // True when the current local time is inside [on, off), wrapping midnight.
    function isInScheduleWindow(date) {
        var now = date || new Date();
        var nowMin = now.getHours() * 60 + now.getMinutes();
        var onMin = root.scheduleOnHour * 60 + root.scheduleOnMinute;
        var offMin = root.scheduleOffHour * 60 + root.scheduleOffMinute;
        if (onMin === offMin) return false;
        if (onMin < offMin) {
            return nowMin >= onMin && nowMin < offMin;
        }
        return nowMin >= onMin || nowMin < offMin;
    }

    // ── Apply ────────────────────────────────────────────────────────────
    Timer {
        id: applyDebounce
        interval: 80
        repeat: false
        onTriggered: root._applyNow()
    }

    function _applyNow() {
        if (!root.available || !root.configReady) return;
        if (root.backend === "hyprsunset") {
            _applyHyprsunset();
        } else if (root.backend === "gammastep") {
            _applyGammastep();
        }
    }

    // hyprsunset: try hyprctl first (daemon running), otherwise start daemon.
    // For "off", ask the daemon to neutralise and then kill it so we don't
    // leave an idle process around.
    function _applyHyprsunset() {
        var temp = String(root.temperature);
        if (root.enabled) {
            Quickshell.execDetached([
                "sh", "-c",
                "hyprctl hyprsunset temperature " + temp + " >/dev/null 2>&1"
                    + " || (pkill -x hyprsunset 2>/dev/null; nohup hyprsunset -t " + temp + " >/dev/null 2>&1 &)"
            ]);
        } else {
            Quickshell.execDetached([
                "sh", "-c",
                "hyprctl hyprsunset identity >/dev/null 2>&1; pkill -x hyprsunset 2>/dev/null; true"
            ]);
        }
    }

    function _applyGammastep() {
        root.gammaRestartPending = root.enabled;
        if (gammaProcess.running) {
            gammaProcess.running = false;
            gammaStopTimeout.restart();
        } else if (root.enabled) {
            startGamma();
        }
    }

    function startGamma() {
        if (!root.enabled || gammaProcess.running) return;
        root.gammaRestartPending = false;
        root.errorMessage = "";
        gammaProcess.command = ["python3", Core.PathService.configPath("scripts/nightlight_process.py"), String(root.temperature)];
        gammaProcess.running = true;
    }

    Process {
        id: gammaProcess
        stdout: SplitParser { onRead: data => {} }
        stderr: SplitParser {
            onRead: data => {
                root.errorMessage = String(data);
                Log.warn("NightLight", data);
            }
        }
        onExited: function(code) {
            gammaStopTimeout.stop();
            if (root.gammaRestartPending && root.enabled) Qt.callLater(root.startGamma);
            else if (root.enabled && code !== 0 && !root.errorMessage)
                root.errorMessage = "Night light could not be applied (exit " + code + ").";
        }
    }
    Timer {
        id: gammaStopTimeout
        interval: 3000
        onTriggered: if (gammaProcess.running) gammaProcess.signal(9)
    }
    Timer {
        interval: 30000
        repeat: true
        running: root.configReady && root.available && root.enabled && root.backend === "gammastep"
        onTriggered: if (!gammaProcess.running) root.startGamma()
    }

    function _reevaluate(forceApply) {
        if (!root.available || !root.configReady) return;

        if (root.scheduleEnabled) {
            var shouldBeOn = isInScheduleWindow();
            if (shouldBeOn !== root.enabled) {
                root.enabled = shouldBeOn;
                saveConfig();
                _applyNow();
                return;
            }
            if (forceApply) _applyNow();
            return;
        }

        if (forceApply && root.applyOnStartup) _applyNow();
    }

    Timer {
        id: scheduleTick
        interval: 1000
        repeat: true
        running: root.scheduleEnabled && root.available
        onTriggered: root._reevaluate(false)
    }

    // ── Persistence ──────────────────────────────────────────────────────
    function saveConfig() {
        configStore.save({
            enabled: root.enabled,
            temperature: root.temperature,
            applyOnStartup: root.applyOnStartup,
            scheduleEnabled: root.scheduleEnabled,
            scheduleOnHour: root.scheduleOnHour,
            scheduleOnMinute: root.scheduleOnMinute,
            scheduleOffHour: root.scheduleOffHour,
            scheduleOffMinute: root.scheduleOffMinute
        });
    }

    Core.JsonDataStore {
        id: configStore
        path: root.configPath
        schemaVersion: 2
        defaultValue: ({
            enabled: false,
            temperature: 4000,
            applyOnStartup: true,
            scheduleEnabled: false,
            scheduleOnHour: 19,
            scheduleOnMinute: 0,
            scheduleOffHour: 7,
            scheduleOffMinute: 0
        })
        function migrate(data, fromVersion) {
            if (fromVersion < 2) {
                if (data.scheduleEnabled === undefined) data.scheduleEnabled = false;
                if (data.scheduleOnHour === undefined) data.scheduleOnHour = 19;
                if (data.scheduleOnMinute === undefined) data.scheduleOnMinute = 0;
                if (data.scheduleOffHour === undefined) data.scheduleOffHour = 7;
                if (data.scheduleOffMinute === undefined) data.scheduleOffMinute = 0;
            }
            return data;
        }
        function validate(data) {
            if (typeof data.enabled !== "boolean") data.enabled = !!data.enabled;
            if (typeof data.applyOnStartup !== "boolean") data.applyOnStartup = !!data.applyOnStartup;
            if (typeof data.scheduleEnabled !== "boolean") data.scheduleEnabled = !!data.scheduleEnabled;
            var t = parseInt(data.temperature);
            if (!isFinite(t) || t < 1000 || t > 6500) t = 4000;
            data.temperature = t;
            function clampHour(v, def) {
                var n = parseInt(v);
                if (!isFinite(n) || n < 0 || n > 23) return def;
                return n;
            }
            function clampMin(v, def) {
                var n = parseInt(v);
                if (!isFinite(n) || n < 0 || n > 59) return def;
                return n;
            }
            data.scheduleOnHour = clampHour(data.scheduleOnHour, 19);
            data.scheduleOnMinute = clampMin(data.scheduleOnMinute, 0);
            data.scheduleOffHour = clampHour(data.scheduleOffHour, 7);
            data.scheduleOffMinute = clampMin(data.scheduleOffMinute, 0);
            return data;
        }
        onLoadedValue: function(cfg) {
            root.enabled = !!cfg.enabled;
            root.temperature = cfg.temperature || 4000;
            root.applyOnStartup = cfg.applyOnStartup !== undefined ? !!cfg.applyOnStartup : true;
            root.scheduleEnabled = !!cfg.scheduleEnabled;
            root.scheduleOnHour = cfg.scheduleOnHour;
            root.scheduleOnMinute = cfg.scheduleOnMinute;
            root.scheduleOffHour = cfg.scheduleOffHour;
            root.scheduleOffMinute = cfg.scheduleOffMinute;
            root.configReady = true;
            if (root.available) _reevaluate(true);
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("NightLight", "Config parse error: " + details);
        }
    }
}
