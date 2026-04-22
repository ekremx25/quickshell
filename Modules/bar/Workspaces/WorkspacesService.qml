import QtQuick
import Quickshell.Io
import "../../../Services"
import "../../../Services/core" as Core
import "../../../Services/core/Log.js" as Log

Item {
    id: service
    visible: false
    width: 0
    height: 0

    required property string monitorName
    required property bool groupApps
    property var tagIconCache: ({})
    property var activeWorkspaces: []
    property var monWsIds: []
    property var monWsMap: ({})
    property string lastStateHash: ""
    property int activeHyprlandWorkspaceId: -1

    function startProcess(proc, nextCommand) {
        if (proc.running) return;
        proc.command = nextCommand;
        proc.running = true;
    }

    function getIcon(appId, title) {
        if (!appId) appId = "";
        if (!title) title = "";
        var c = appId.toLowerCase();
        var t = title.toLowerCase();
        if (t.includes("amazon")) return " ";
        if (t.includes("reddit")) return " ";
        if (t.includes("gmail")) return "󰊫 ";
        if (t.includes("whatsapp")) return " ";
        if (t.includes("zapzap")) return " ";
        if (t.includes("messenger")) return " ";
        if (t.includes("facebook")) return " ";
        if (t.match(/chatgpt|deepseek|qwen/)) return "󰚩 ";
        if (t.includes("picture-in-picture")) return " ";
        if (t.includes("youtube")) return " ";
        if (t.includes("cmus")) return " ";
        if (t.includes("virtualbox")) return "💽 ";
        if (t.includes("github")) return " ";
        if (t.match(/nvim ~|vim|nvim/)) return " ";
        if (t.includes("figma")) return " ";
        if (t.includes("jira")) return " ";
        if (t.includes("x")) return "\ueb72";
        if (t.includes("google")) return "\ue7f0";
        if (t.includes("flow")) return "\ue69f";
        if (t.includes("dolphin")) return "󰝰 ";
        if (t.includes("kwrite")) return " ";
        if (c.match(/firefox|org\.mozilla\.firefox|librewolf|floorp|mercury-browser|cachy-browser/)) return " ";
        if (c.match(/zen/)) return "󰰷 ";
        if (c.match(/waterfox|waterfox-bin/)) return " ";
        if (c.match(/microsoft-edge/)) return " ";
        if (c.match(/chromium|thorium|chrome/)) return " ";
        if (c.match(/brave-browser/)) return "🦁 ";
        if (c.match(/tor browser/)) return " ";
        if (c.match(/firefox-developer-edition/)) return "🦊 ";
        if (c.match(/kitty|konsole/)) return " ";
        if (c.match(/kitty-dropterm/)) return " ";
        if (c.match(/com\.mitchellh\.ghostty/)) return "  ";
        if (c.match(/org\.wezfurlong\.wezterm/)) return "  ";
        if (c.match(/thunderbird|thunderbird-esr|eu\.betterbird\.betterbird/)) return " ";
        if (c.match(/telegram-desktop|org\.telegram\.desktop|io\.github\.tdesktop_x64\.tdesktop/)) return " ";
        if (c.match(/discord|webcord|vesktop/)) return " ";
        if (c.match(/subl/)) return "󰅳 ";
        if (c.match(/slack/)) return " ";
        if (c.match(/mpv/)) return " ";
        if (c.match(/celluloid|zoom/)) return " ";
        if (c.match(/cider/)) return "󰎆 ";
        if (c.match(/vlc/)) return "󰕼 ";
        if (c.match(/spotify/)) return " ";
        if (c.match(/virt-manager|\.virt-manager-wrapped/)) return " ";
        if (c.match(/virtualbox manager/)) return "💽 ";
        if (c.match(/remmina/)) return "🖥️ ";
        if (c.match(/vscode|code-url-handler|code-oss|codium|codium-url-handler|vscodium/)) return "󰨞 ";
        if (c.match(/dev\.zed\.zed/)) return "󰵁 ";
        if (c.match(/codeblocks/)) return "󰅩 ";
        if (c.match(/mousepad/)) return " ";
        if (c.match(/libreoffice-writer/)) return " ";
        if (c.match(/libreoffice-startcenter/)) return "󰏆 ";
        if (c.match(/libreoffice-calc/)) return " ";
        if (c.match(/jetbrains-idea/)) return " ";
        if (c.match(/obs|com\.obsproject\.studio/)) return " ";
        if (c.match(/polkit-gnome-authentication-agent-1/)) return "󰒃 ";
        if (c.match(/nwg-look/)) return " ";
        if (c.match(/pavucontrol|org\.pulseaudio\.pavucontrol/)) return "󱡫 ";
        if (c.match(/steam/)) return " ";
        if (c.match(/thunar|nemo|dolphin/)) return "󰝰 ";
        if (c.match(/kwrite/)) return " ";
        if (c.match(/gparted/)) return " ";
        if (c.match(/gimp/)) return " ";
        if (c.match(/emulator/)) return "📱 ";
        if (c.match(/android-studio/)) return " ";
        if (c.match(/org\.pipewire\.helvum/)) return "󰓃 ";
        if (c.match(/localsend/)) return " ";
        if (c.match(/prusaslicer|ultimaker-cura|orcaslicer/)) return "󰹛 ";
        return " ";
    }

    function finalizeWorkspaceState(result, alwaysVisibleCount) {
        var existingNames = [];
        for (var i = 0; i < result.length; i++) existingNames.push(String(result[i].name));
        for (var k = 1; k <= alwaysVisibleCount; k++) {
            var strK = String(k);
            if (existingNames.indexOf(strK) === -1) result.push({ id: strK, idx: k, name: strK, is_active: false, winCount: 0, clients: 0, windows: [], groupedWindows: [] });
        }
        result.sort(function(a, b) {
            var numA = parseInt(a.name);
            var numB = parseInt(b.name);
            if (!isNaN(numA) && !isNaN(numB)) return numA - numB;
            return 0;
        });
        var currentState = JSON.stringify(result);
        if (service.lastStateHash !== currentState) {
            service.lastStateHash = currentState;
            service.activeWorkspaces = result;
        }
    }

    function buildGroupedWindows(windows, isWorkspaceActive) {
        var groups = {};
        for (var i = 0; i < windows.length; i++) {
            var w = windows[i];
            var appKey = w.app_id || w.title || "unknown";
            var icon = getIcon(w.app_id, w.title);
            if (!groups[appKey]) groups[appKey] = { icon: icon, active: w.is_active, count: 1 };
            else {
                groups[appKey].count++;
                if (w.is_active) groups[appKey].active = true;
            }
        }
        var groupedArr = [];
        for (var key in groups) {
            if (!service.groupApps || isWorkspaceActive) {
                for (var j = 0; j < groups[key].count; j++) groupedArr.push({ icon: groups[key].icon, active: groups[key].active });
            } else groupedArr.push(groups[key]);
        }
        return groupedArr;
    }

    function workspacesCommand() {
        if (CompositorService.isHyprland) return ["hyprctl", "workspaces", "-j"];
        if (CompositorService.isMango) return ["mmsg", "-g", "-t"];
        return ["niri", "msg", "-j", "workspaces"];
    }

    function windowsCommand() {
        if (CompositorService.isHyprland) return ["hyprctl", "clients", "-j"];
        if (CompositorService.isMango) return ["echo", ""];
        return ["niri", "msg", "-j", "windows"];
    }

    function focusCommand(targetName) {
        if (CompositorService.isHyprland) return ["hyprctl", "dispatch", "workspace", String(targetName)];
        if (CompositorService.isNiri) return ["niri", "msg", "action", "focus-workspace", String(targetName)];
        return ["mmsg", "-s", "-o", monitorName, "-t", String(targetName)];
    }

    function updateMonitorWorkspaceState(ids, map) {
        ids.sort(function(a, b) {
            var left = map[a].idx !== undefined ? map[a].idx : a;
            var right = map[b].idx !== undefined ? map[b].idx : b;
            return left - right;
        });
        service.monWsIds = ids;
        service.monWsMap = map;
    }

    function collectMangoMonitorWindows() {
        var monitorWindows = [];
        var toplevels = ToplevelManager.toplevels;
        var tlValues = toplevels.values || [];
        for (var ti = 0; ti < tlValues.length; ti++) {
            var tl = tlValues[ti];
            var onThisScreen = false;
            if (tl.screens) {
                for (var si = 0; si < tl.screens.length; si++) {
                    if (tl.screens[si].name === monitorName) {
                        onThisScreen = true;
                        break;
                    }
                }
            }
            if (onThisScreen) monitorWindows.push({ app_id: tl.appId || "", title: tl.title || "", is_active: tl.activated || false });
        }
        return monitorWindows;
    }

    function parseMangoWorkspaceState(text) {
        var lines = text.trim().split("\n");
        var ids = [];
        var map = {};
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "") continue;
            var parts = line.split(/\s+/);
            if (parts.length < 2 || parts[0] !== monitorName) continue;
            if (parts[1] === "tag" && parts.length >= 6) {
                var tagNum = parseInt(parts[2]);
                var state = parseInt(parts[3]);
                if (!isNaN(tagNum)) {
                    ids.push(tagNum);
                    map[tagNum] = { id: tagNum, idx: tagNum, name: String(tagNum), is_active: state === 1, clients: parseInt(parts[4]) || 0, focused: parseInt(parts[5]) || 0 };
                }
            }
        }
        updateMonitorWorkspaceState(ids, map);
        return collectMangoMonitorWindows();
    }

    function parseStandardWorkspaceState(text) {
        var allWs = JSON.parse(text);
        var ids = [];
        var map = {};
        for (var i = 0; i < allWs.length; i++) {
            var ws = allWs[i];
            if (CompositorService.isHyprland) {
                if (ws.monitor === monitorName) {
                    ids.push(ws.id);
                    map[ws.id] = { id: ws.id, idx: ws.id, name: ws.name ? ws.name : String(ws.id), is_active: ws.id === activeHyprlandWorkspaceId };
                }
            } else if (ws.output === monitorName) {
                ids.push(ws.id);
                map[ws.id] = { id: ws.id, idx: ws.idx !== undefined ? ws.idx : (i + 1), name: ws.name ? ws.name : String(ws.idx !== undefined ? ws.idx : (i + 1)), is_active: ws.is_focused ?? false };
            }
        }
        updateMonitorWorkspaceState(ids, map);
    }

    function refresh() {
        if (CompositorService.isHyprland) startProcess(activeWsProc, ["hyprctl", "activeworkspace", "-j"]);
        startProcess(wsProc, workspacesCommand());
        startProcess(winProc, windowsCommand());
    }

    function switchToWorkspace(targetName) {
        startProcess(focusProc, focusCommand(targetName));
    }

    Process { id: focusProc; command: [] }

    Process {
        id: wsProc
        command: workspacesCommand()
        property string outputBuffer: ""
        stdout: SplitParser { onRead: data => wsProc.outputBuffer += data + "\n" }
        onExited: {
            if (wsProc.outputBuffer.trim() === "") return;
            try {
                if (CompositorService.isMango) {
                    var monitorWindows = parseMangoWorkspaceState(wsProc.outputBuffer);
                    var result = [];
                    for (var j = 0; j < service.monWsIds.length; j++) {
                        var id = service.monWsIds[j];
                        var ws = service.monWsMap[id];
                        ws.windows = [];
                        ws.groupedWindows = [];
                        ws.winCount = ws.clients || 0;
                        if (ws.is_active && monitorWindows.length > 0) {
                            var tagClientCount = ws.clients || 0;
                            var sorted = monitorWindows.slice().sort(function(a, b) { return (b.is_active ? 1 : 0) - (a.is_active ? 1 : 0); });
                            var visibleWindows = tagClientCount > 0 ? sorted.slice(0, tagClientCount) : sorted;
                            for (var wi = 0; wi < visibleWindows.length; wi++) ws.windows.push(visibleWindows[wi]);
                            ws.groupedWindows = buildGroupedWindows(ws.windows, ws.is_active);
                            var cache = service.tagIconCache;
                            cache[id] = { windows: ws.windows, groupedWindows: ws.groupedWindows };
                            service.tagIconCache = cache;
                        } else if (ws.winCount > 0 && service.tagIconCache[id]) {
                            var cached = service.tagIconCache[id];
                            ws.windows = cached.windows;
                            ws.groupedWindows = cached.groupedWindows;
                        }
                        result.push(ws);
                    }
                    finalizeWorkspaceState(result, 9);
                } else parseStandardWorkspaceState(wsProc.outputBuffer);
            } catch (e) {
                Log.warn("WorkspacesService", "Workspace state parse error: " + e);
            }
            wsProc.outputBuffer = "";
        }
    }

    Process {
        id: activeWsProc
        command: ["hyprctl", "activeworkspace", "-j"]
        property string outputBuffer: ""
        stdout: SplitParser { onRead: data => activeWsProc.outputBuffer += data }
        onExited: {
            if (activeWsProc.outputBuffer.trim() === "") return;
            try {
                var obj = JSON.parse(activeWsProc.outputBuffer);
                service.activeHyprlandWorkspaceId = obj.id;
            } catch (e) {
                Log.warn("WorkspacesService", "Active workspace parse error: " + e);
            }
            activeWsProc.outputBuffer = "";
        }
    }

    Process {
        id: winProc
        command: windowsCommand()
        property string outputBuffer: ""
        stdout: SplitParser { onRead: data => winProc.outputBuffer += data }
        onExited: {
            if (CompositorService.isMango) {
                winProc.outputBuffer = "";
                return;
            }
            if (winProc.outputBuffer.trim() === "") return;
            try {
                var allWindows = JSON.parse(winProc.outputBuffer);
                var wsMap = service.monWsMap ?? {};
                var ids = service.monWsIds ?? [];
                for (var wsId in wsMap) {
                    wsMap[wsId].windows = [];
                    wsMap[wsId].winCount = 0;
                }
                for (var i = 0; i < allWindows.length; i++) {
                    var win = allWindows[i];
                    if (CompositorService.isHyprland) {
                        if (win.workspace && ids.includes(win.workspace.id)) {
                            var hyprId = win.workspace.id;
                            if (wsMap[hyprId]) {
                                var isFocused = win.focusHistoryID === 0;
                                wsMap[hyprId].windows.push({ app_id: win.class, title: win.title, is_active: isFocused });
                                wsMap[hyprId].winCount++;
                            }
                        }
                    } else if (ids.includes(win.workspace_id)) {
                        var niriId = win.workspace_id;
                        if (wsMap[niriId]) {
                            wsMap[niriId].windows.push({ app_id: win.app_id, title: win.title, is_active: win.is_focused });
                            wsMap[niriId].winCount++;
                            if (win.is_focused) wsMap[niriId].is_active = true;
                        }
                    }
                }
                for (var key in wsMap) wsMap[key].groupedWindows = buildGroupedWindows(wsMap[key].windows, wsMap[key].is_active);
                var result = [];
                for (var j = 0; j < ids.length; j++) result.push(wsMap[ids[j]]);
                finalizeWorkspaceState(result, 5);
            } catch (e) {
                Log.warn("WorkspacesService", "Window state parse error: " + e);
            }
            winProc.outputBuffer = "";
        }
    }

    // ----------------------------------------------------------------
    // Hyprland: .socket2 event stream (event-driven, no polling)
    // ----------------------------------------------------------------
    // Listens for events from the Hyprland socket; calls refresh() with
    // a 50ms debounce on workspace/window changes.
    // If the connection drops, auto-reconnects after 1s.
    // If socat/nc is missing (exit 127), polling fallback kicks in.
    property bool _hyprFallback: false

    Process {
        id: hyprEventProc
        running: CompositorService.isHyprland && !service._hyprFallback
        command: CompositorService.isHyprland
            ? ["bash", Core.PathService.configPath("scripts/hypr_events.sh")]
            : []

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line) return;
                // Events that trigger a workspace or window change
                if (line.startsWith("workspace>>")   ||
                    line.startsWith("openwindow>>")  ||
                    line.startsWith("closewindow>>") ||
                    line.startsWith("movewindow>>")  ||
                    line.startsWith("activewindow>>") ||
                    line.startsWith("focusedmon>>")  ||
                    line.startsWith("windowtitle>>")) {
                    hyprDebounce.restart();
                }
            }
        }

        onExited: exitCode => {
            if (!CompositorService.isHyprland) return;
            if (exitCode === 127) {
                // socat/nc not available → polling fallback
                Log.warn("WorkspacesService", "Hyprland event stream unavailable, switching to polling mode");
                service._hyprFallback = true;
                return;
            }
            // Temporary disconnect (compositor restart etc.) → reconnect after 1s
            Log.info("WorkspacesService", "Hyprland event stream closed (code: " + exitCode + "), reconnecting");
            hyprReconnectTimer.restart();
        }
    }

    Timer {
        id: hyprDebounce
        interval: 50
        repeat: false
        onTriggered: service.refresh()
    }

    Timer {
        id: hyprReconnectTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (CompositorService.isHyprland && !hyprEventProc.running) {
                hyprEventProc.running = true;
            }
        }
    }

    // ----------------------------------------------------------------
    // Hyprland fallback + MangoWC: polling (700ms)
    // Hyprland: only active if socat/nc is missing.
    // MangoWC: always active (no event stream API).
    // Niri: never runs because Niri.qml uses its own event stream.
    // ----------------------------------------------------------------
    Timer {
        interval: 700
        running: CompositorService.isMango || (CompositorService.isHyprland && service._hyprFallback)
        repeat: true
        onTriggered: service.refresh()
    }
}
