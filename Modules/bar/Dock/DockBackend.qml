import QtQuick
import Qt.labs.platform
import Quickshell.Io
import "../../../Services" as S
import "AppService.js" as AppService
import "../../../Services/core/Log.js" as Log

Item {
    id: backend
    visible: false
    width: 0
    height: 0

    property bool is4K: false
    property bool suspendHotReload: false

    property alias dockConfigData: dockData.dockConfigData
    property alias pinnedApps: dockData.pinnedApps
    property alias leftModules: dockData.leftModules
    property alias rightModules: dockData.rightModules
    property alias runningWindows: dockData.runningWindows
    property alias desktopIcons: dockData.desktopIcons
    property alias desktopCommands: dockData.desktopCommands
    property alias desktopEntries: dockData.desktopEntries
    property alias lastDockConfigContent: dockData.lastDockConfigContent
    property alias windowTrackingEnabled: dockData.windowTrackingEnabled
    property alias windowRefreshInterval: dockData.windowRefreshInterval
    property var dockItems: []

    DockDataService {
        id: dockData
        suspendHotReload: backend.suspendHotReload
    }

    function setProcessCommand(proc, nextCommand) {
        proc.running = false;
        proc.command = nextCommand;
        proc.running = true;
    }

    function logToFile(msg) {
        Log.debug("DockBackend", String(msg || ""));
    }

    function normalizeAppId(appId) {
        return AppService.normalizeAppId(appId);
    }

    function resolveDesktopKey(rawId) {
        return AppService.resolveDesktopKey(rawId, desktopEntries, desktopIcons, desktopCommands);
    }

    function resolveThemedIconName(iconName) {
        return AppService.resolveThemedIconName(iconName);
    }

    function getIcon(appId) {
        return AppService.getIcon(appId, desktopIcons, desktopEntries, desktopCommands);
    }

    function getAppName(appId) {
        return AppService.getAppName(appId);
    }

    function getCmd(appId) {
        return AppService.getCmd(appId, desktopEntries, desktopCommands);
    }

    function cmdFromDesktopId(desktopId) {
        if (!desktopId) return "";
        var keys = Object.keys(desktopEntries);
        for (var i = 0; i < keys.length; i++) {
            var key = keys[i];
            if (desktopEntries[key] === desktopId && desktopCommands[key]) return desktopCommands[key];
        }
        return "";
    }

    function expandIconPath(icon) {
        var resolvedIcon = icon || "";
        if (resolvedIcon.indexOf("~") === 0) {
            resolvedIcon = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + resolvedIcon.substring(1);
        }
        var lowered = resolvedIcon.toLowerCase();
        if (desktopIcons[lowered]) return desktopIcons[lowered];
        return resolvedIcon;
    }

    function createPinnedEntry(appId) {
        return {
            name: getAppName(appId),
            icon: String(appId || "").toLowerCase(),
            cmd: getCmd(appId),
            appId: appId
        };
    }

    function buildPinnedDockItem(pinnedApp) {
        var isRunning = false;
        var windowId = -1;

        for (var i = 0; i < runningWindows.length; i++) {
            var runningId = normalizeAppId(runningWindows[i].app_id);
            if (runningId === pinnedApp.appId) {
                isRunning = true;
                windowId = runningWindows[i].id;
                break;
            }
        }

        var rawIcon = pinnedApp.icon && pinnedApp.icon !== "" ? pinnedApp.icon : getIcon(pinnedApp.appId);
        return {
            name: getAppName(pinnedApp.appId),
            icon: expandIconPath(rawIcon),
            cmd: getCmd(pinnedApp.appId),
            appId: pinnedApp.appId,
            isPinned: true,
            isRunning: isRunning,
            windowId: windowId,
            isModule: false
        };
    }

    function buildRunningDockItem(windowInfo) {
        var rawId = windowInfo.app_id || "";
        return {
            name: getAppName(rawId),
            icon: getIcon(rawId),
            cmd: rawId,
            appId: normalizeAppId(rawId),
            isPinned: false,
            isRunning: true,
            windowId: windowInfo.id,
            isModule: false
        };
    }

    function rebuildDockItems() {
        var items = [];
        var pinnedIds = {};
        var seenIds = {};

        for (var i = 0; i < pinnedApps.length; i++) {
            var pinned = pinnedApps[i];
            pinnedIds[pinned.appId] = true;
            items.push(buildPinnedDockItem(pinned));
        }

        for (var j = 0; j < runningWindows.length; j++) {
            var win = runningWindows[j];
            var normId = normalizeAppId(win.app_id || "");
            if (normId === "" || pinnedIds[normId] || seenIds[normId]) continue;
            seenIds[normId] = true;
            items.push(buildRunningDockItem(win));
        }

        dockItems = items;
    }

    function savePinnedApps() {
        dockData.persistDockState(pinnedApps, leftModules, rightModules);
    }

    function setPinnedApps(nextPinnedApps) {
        pinnedApps = nextPinnedApps;
        savePinnedApps();
        rebuildDockItems();
    }

    function pinApp(appId) {
        for (var i = 0; i < pinnedApps.length; i++) {
            if (pinnedApps[i].appId === appId) return;
        }
        var nextPinned = pinnedApps.slice();
        nextPinned.push(createPinnedEntry(appId));
        logToFile("pinApp: " + appId);
        setPinnedApps(nextPinned);
    }

    function pinAppAt(appId, targetIndex) {
        for (var i = 0; i < pinnedApps.length; i++) {
            if (pinnedApps[i].appId === appId) return;
        }
        var nextPinned = pinnedApps.slice();
        var newItem = createPinnedEntry(appId);
        if (targetIndex >= 0 && targetIndex <= nextPinned.length) nextPinned.splice(targetIndex, 0, newItem);
        else nextPinned.push(newItem);
        setPinnedApps(nextPinned);
    }

    function reorderPinned(fromIdx, toIdx) {
        if (fromIdx < 0 || fromIdx >= pinnedApps.length) return;
        if (toIdx < 0) toIdx = 0;
        if (toIdx >= pinnedApps.length) toIdx = pinnedApps.length - 1;
        if (fromIdx === toIdx) return;

        var nextPinned = pinnedApps.slice();
        var item = nextPinned.splice(fromIdx, 1)[0];
        nextPinned.splice(toIdx, 0, item);
        logToFile("reorderPinned: from " + fromIdx + " to " + toIdx);
        setPinnedApps(nextPinned);
    }

    function unpinApp(appId) {
        var nextPinned = [];
        for (var i = 0; i < pinnedApps.length; i++) {
            if (pinnedApps[i].appId !== appId) nextPinned.push(pinnedApps[i]);
        }
        setPinnedApps(nextPinned);
    }

    function shellQuote(value) {
        if (value === undefined || value === null) return "''";
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function detachedWrap(rawCmd) {
        if (!rawCmd) return "";
        return "nohup sh -lc " + shellQuote(rawCmd) + " >/dev/null 2>&1 &";
    }

    function runDetachedCommand(rawCmd) {
        if (!rawCmd) return;
        setProcessCommand(launchProc, ["/bin/sh", "-lc", detachedWrap(rawCmd)]);
    }

    function launchApp(cmd) {
        if (!cmd) return;
        if (cmd.indexOf("__desktop__:") === 0) {
            var desktopId = cmd.substring("__desktop__:".length);
            if (desktopId.indexOf("/") !== -1 || desktopId.indexOf(" ") !== -1) {
                logToFile("launch branch=desktop-malformed cmd=" + desktopId);
                runDetachedCommand(desktopId);
                return;
            }

            var desktopExec = cmdFromDesktopId(desktopId);
            if (desktopExec !== "") {
                logToFile("launch branch=desktop-exec id=" + desktopId + " exec=" + desktopExec);
                runDetachedCommand(desktopExec);
                return;
            }

            logToFile("launch branch=gtk-launch id=" + desktopId);
            runDetachedCommand("/usr/bin/gtk-launch " + shellQuote(desktopId));
            return;
        }

        if (cmd.indexOf("__steam_game__:") === 0) {
            var gameId = cmd.substring("__steam_game__:".length).replace(/[^0-9]/g, "");
            if (gameId.length > 0) {
                var steamUrl = "steam://rungameid/" + gameId;
                logToFile("launch branch=steam id=" + gameId);
                runDetachedCommand("if command -v steam >/dev/null 2>&1; then steam " + shellQuote(steamUrl) + "; else flatpak run com.valvesoftware.Steam " + shellQuote(steamUrl) + "; fi");
                return;
            }
        }

        logToFile("launch branch=shell cmd=" + cmd);
        runDetachedCommand(cmd);
    }

    function focusWindow(windowId) {
        setProcessCommand(
            focusProc,
            S.CompositorService.isHyprland
                ? ["hyprctl", "dispatch", "focuswindow", "address:" + windowId]
                : ["niri", "msg", "action", "focus-window", "--id", "" + windowId]
        );
    }

    function closeWindow(windowId) {
        setProcessCommand(
            launchProc,
            S.CompositorService.isHyprland
                ? ["hyprctl", "dispatch", "closewindow", "address:" + windowId]
                : ["niri", "msg", "action", "close-window", "--id", "" + windowId]
        );
    }

    Process {
        id: launchProc
        command: []
        running: false
        stdout: SplitParser { onRead: data => backend.logToFile("launch stdout: " + data) }
        stderr: SplitParser { onRead: data => backend.logToFile("launch stderr: " + data) }
        onExited: code => backend.logToFile("launch exit: " + code + " cmd=" + JSON.stringify(command))
    }

    Process { id: focusProc; command: []; running: false }
    Connections {
        target: dockData

        function onDockConfigDataChanged() {
            backend.rebuildDockItems();
        }

        function onRunningWindowsChanged() {
            backend.rebuildDockItems();
        }

        function onDesktopIconsChanged() {
            backend.rebuildDockItems();
        }
    }
}
