import QtQuick
import Quickshell.Io
import "../../../Services" as S
import "../../../Services/core" as Core
import "../../../Services/core/Log.js" as Log

Item {
    id: service
    visible: false
    width: 0
    height: 0

    property string configPath: Core.PathService.configPath("dock_config.json")
    property string desktopIconScript: Core.PathService.configPath("scripts/desktop_icons.sh")
    property string initDockScript: Core.PathService.configPath("scripts/init_dock.sh")

    property var dockConfigData: null
    property var pinnedApps: []
    property var leftModules: []
    property var rightModules: []
    property var runningWindows: []
    property bool suspendHotReload: false

    property var desktopIcons: ({})
    property var desktopCommands: ({})
    property var desktopEntries: ({})
    property string lastDockConfigContent: ""
    property bool windowRefreshRunning: false
    property bool windowTrackingEnabled: true
    property int windowRefreshInterval: 2500

    function parseDesktopMetadata(raw) {
        var parts = [];
        var depth = 0;
        var startIdx = -1;

        for (var ci = 0; ci < raw.length; ci++) {
            if (raw[ci] === "{") {
                if (depth === 0) startIdx = ci;
                depth++;
            } else if (raw[ci] === "}") {
                depth--;
                if (depth === 0 && startIdx >= 0) {
                    parts.push(raw.substring(startIdx, ci + 1));
                    startIdx = -1;
                }
            }
        }

        if (parts.length === 0) {
            return {
                icons: JSON.parse(raw),
                commands: {},
                entries: {}
            };
        }

        return {
            icons: JSON.parse(parts[0]),
            commands: parts.length > 1 ? JSON.parse(parts[1]) : {},
            entries: parts.length > 2 ? JSON.parse(parts[2]) : {}
        };
    }

    function cloneDockConfig() {
        var obj = {};
        if (!service.dockConfigData) return obj;

        var keys = Object.keys(service.dockConfigData);
        for (var i = 0; i < keys.length; i++) obj[keys[i]] = service.dockConfigData[keys[i]];
        return obj;
    }

    function normalizeModuleList(list) {
        var normalized = [];
        if (!Array.isArray(list)) return normalized;

        var allowed = ({
            "Launcher": true,
            "Weather": true,
            "Volume": true,
            "Tray": true,
            "Notepad": true,
            "Power": true,
            "Clipboard": true,
            "Media": true
        });
        var seen = ({});

        for (var i = 0; i < list.length; i++) {
            var name = list[i];
            if (!allowed[name] || seen[name]) continue;
            seen[name] = true;
            normalized.push(name);
        }

        return normalized;
    }

    function normalizeDockConfig(cfg) {
        var normalized = cfg || {};
        var legacyModules = normalizeModuleList(normalized.modules || []);
        var left = normalizeModuleList(normalized.leftModules || []);
        var right = normalizeModuleList(normalized.rightModules || []);

        if (left.length === 0 && right.length === 0 && legacyModules.length > 0) {
            left = legacyModules.indexOf("Weather") !== -1 ? ["Weather"] : [];
            right = legacyModules.filter(function(name) {
                return name !== "Weather" && name !== "Launcher";
            });
        }

        normalized.leftModules = left;
        normalized.rightModules = right;
        delete normalized.modules;

        if (normalized.showDock === undefined) normalized.showDock = true;
        if (normalized.showBackground === undefined) normalized.showBackground = true;
        if (normalized.dockScale === undefined) normalized.dockScale = 1.0;
        if (normalized.autoHide === undefined) normalized.autoHide = false;
        return normalized;
    }

    function applyDockConfig(cfg, rawContent) {
        cfg = normalizeDockConfig(cfg);
        service.lastDockConfigContent = rawContent || service.lastDockConfigContent;
        service.dockConfigData = cfg;
        service.pinnedApps = cfg.pinned || [];
        service.leftModules = cfg.leftModules || [];
        service.rightModules = cfg.rightModules || [];

        var showBg = cfg.showBackground !== undefined ? cfg.showBackground : true;
        if (service.dockConfigData.showBackground !== showBg) service.dockConfigData.showBackground = showBg;
    }

    function handleDockConfigText(content) {
        if (service.suspendHotReload) return;
        var trimmed = (content || "").trim();
        if (trimmed === "" && service.lastDockConfigContent === "") {
            initDockProc.running = true;
            return;
        }
        if (trimmed === "" || trimmed === service.lastDockConfigContent) return;

        try {
            applyDockConfig(JSON.parse(trimmed), trimmed);
        } catch (e) {
            Log.warn("DockDataService", "Dock config parse error: " + e);
        }
    }

    function windowQueryCommand() {
        return S.CompositorService.isHyprland
            ? ["hyprctl", "clients", "-j"]
            : ["niri", "msg", "-j", "windows"];
    }

    function normalizeRunningWindows(parsed) {
        if (!S.CompositorService.isHyprland) return parsed;

        var normalized = [];
        for (var i = 0; i < parsed.length; i++) {
            normalized.push({
                app_id: parsed[i].class || "",
                id: parsed[i].address || ""
            });
        }
        return normalized;
    }

    function persistDockState(nextPinnedApps, nextLeftModules, nextRightModules) {
        var obj = cloneDockConfig();
        if (!obj || Object.keys(obj).length === 0) {
            try {
                obj = JSON.parse(service.lastDockConfigContent || "{}");
            } catch (e) {
                obj = {};
            }
        }
        obj.pinned = nextPinnedApps || [];
        obj.leftModules = nextLeftModules || [];
        obj.rightModules = nextRightModules || [];
        obj = normalizeDockConfig(obj);

        var nextContent = JSON.stringify(obj, null, 2);
        applyDockConfig(obj, nextContent);
        dockConfigStore.save(obj);
    }

    function refreshWindows() {
        if (winProc.running) return;
        service.windowRefreshRunning = true;
        winProc.command = windowQueryCommand();
        winProc.running = true;
    }

    Process {
        id: initDockProc
        command: ["bash", service.initDockScript]
        onExited: dockConfigStore.load()
    }

    Core.JsonDataStore {
        id: dockConfigStore
        path: service.configPath
        defaultValue: ({})
        onLoadedValue: (_, rawText) => service.handleDockConfigText(rawText)
        onFailed: (phase, exitCode, details) => Log.warn("DockDataService", phase + " failed (" + exitCode + "): " + details)
    }

    Core.FileChangeWatcher {
        id: dockConfigWatcher
        path: service.configPath
        interval: 800
        active: !service.suspendHotReload
        onChanged: dockConfigStore.load()
    }

    Process {
        id: desktopIconProc
        command: ["bash", service.desktopIconScript]
        property string outputBuffer: ""
        stdout: SplitParser { onRead: data => desktopIconProc.outputBuffer += data + "\n" }
        onExited: {
            if (desktopIconProc.outputBuffer.trim() !== "") {
                try {
                    var parsed = parseDesktopMetadata(desktopIconProc.outputBuffer.trim());
                    service.desktopIcons = parsed.icons;
                    service.desktopCommands = parsed.commands;
                    service.desktopEntries = parsed.entries;
                } catch (e) {
                    Log.warn("DockDataService", "Desktop icons parse error: " + e);
                }
            }
            desktopIconProc.outputBuffer = "";
        }
        Component.onCompleted: running = true
    }

    Process {
        id: winProc
        command: service.windowQueryCommand()
        property string outputBuffer: ""
        stdout: SplitParser { onRead: data => winProc.outputBuffer += data }
        onExited: {
            if (winProc.outputBuffer.trim() !== "") {
                try {
                    service.runningWindows = service.normalizeRunningWindows(JSON.parse(winProc.outputBuffer));
                } catch (e) {
                    Log.warn("DockDataService", "Running windows parse error: " + e);
                }
            }
            winProc.outputBuffer = "";
            service.windowRefreshRunning = false;
        }
    }

    // ----------------------------------------------------------------
    // Hyprland: pencere event stream (event-driven, polling yok)
    // hypr_events.sh → openwindow/closewindow/movewindow olaylarında
    // 80ms debounce ile refreshWindows() çağırır.
    // ----------------------------------------------------------------
    property bool _hyprFallback: false

    Process {
        id: hyprWinEventProc
        running: S.CompositorService.isHyprland && service.windowTrackingEnabled && !service._hyprFallback
        command: ["bash", Core.PathService.configPath("scripts/hypr_events.sh")]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line.startsWith("openwindow>>")  ||
                    line.startsWith("closewindow>>") ||
                    line.startsWith("movewindow>>")  ||
                    line.startsWith("activewindow>>")) {
                    dockWinDebounce.restart();
                }
            }
        }
        onExited: exitCode => {
            if (!S.CompositorService.isHyprland) return;
            if (exitCode === 127) {
                service._hyprFallback = true;
                return;
            }
            hyprWinReconnect.restart();
        }
    }

    Timer {
        id: hyprWinReconnect
        interval: 1000; repeat: false
        onTriggered: {
            if (S.CompositorService.isHyprland && !hyprWinEventProc.running)
                hyprWinEventProc.running = true;
        }
    }

    // ----------------------------------------------------------------
    // Niri: pencere event stream (event-driven, polling yok)
    // WindowsChanged ve WindowFocusChanged olaylarında günceller.
    // ----------------------------------------------------------------
    Process {
        id: niriWinEventProc
        running: S.CompositorService.isNiri && service.windowTrackingEnabled
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var event = JSON.parse(data.trim());
                    if (event.WindowsChanged || event.WindowFocusChanged) {
                        dockWinDebounce.restart();
                    }
                } catch (e) {}
            }
        }
        onExited: exitCode => {
            if (S.CompositorService.isNiri) niriWinReconnect.restart();
        }
    }

    Timer {
        id: niriWinReconnect
        interval: 2000; repeat: false
        onTriggered: {
            if (S.CompositorService.isNiri && !niriWinEventProc.running)
                niriWinEventProc.running = true;
        }
    }

    // ----------------------------------------------------------------
    // Debounce — hızlı ardışık olayları tek refresh'e indirger
    // ----------------------------------------------------------------
    Timer {
        id: dockWinDebounce
        interval: 80
        repeat: false
        onTriggered: service.refreshWindows()
    }

    // ----------------------------------------------------------------
    // Polling fallback
    // MangoWC: her zaman (event API yok)
    // Hyprland: sadece hypr_events.sh çalışmazsa (socat/nc yok)
    // ----------------------------------------------------------------
    Timer {
        interval: service.windowRefreshInterval
        running: service.windowTrackingEnabled && (
            S.CompositorService.isMango ||
            (S.CompositorService.isHyprland && service._hyprFallback)
        )
        repeat: true
        onTriggered: service.refreshWindows()
    }

    Component.onCompleted: {
        dockConfigStore.load();
        // Event stream başlamadan önce mevcut pencere listesini al
        service.refreshWindows();
    }
}
