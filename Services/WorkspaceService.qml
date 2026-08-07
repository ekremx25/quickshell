pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./core" as Core
import "./core/WorkspaceLogic.js" as WorkspaceLogic
import "./core/Log.js" as Log

Singleton {
    id: root

    property var state: ({ monitorOrder: [], byMonitor: {}, global: [] })
    property int revision: 0
    property bool available: false
    property bool refreshPending: false
    property bool eventFallback: false
    property string lastError: ""
    property var pendingAction: []

    readonly property string snapshotScript: Core.PathService.configPath("scripts/workspace_snapshot.sh")
    readonly property string workspaceScript: Core.PathService.configPath("scripts/hypr_workspace_apply.sh")

    Component.onCompleted: requestRefresh()

    function section(text, startMarker, endMarker) {
        var start = text.indexOf(startMarker)
        if (start < 0) return ""
        start += startMarker.length
        var end = text.indexOf(endMarker, start)
        if (end < 0) end = text.length
        return text.substring(start, end).trim()
    }

    function applyState(nextState) {
        root.state = nextState || ({ monitorOrder: [], byMonitor: {}, global: [] })
        root.available = true
        root.lastError = ""
        root.revision++
    }

    function parseHyprlandSnapshot(text) {
        var monitors = JSON.parse(section(text, "<<<MONITORS>>>", "<<<WORKSPACES>>>" ) || "[]")
        var workspaces = JSON.parse(section(text, "<<<WORKSPACES>>>", "<<<CLIENTS>>>") || "[]")
        var clients = JSON.parse(section(text, "<<<CLIENTS>>>", "<<<END>>>") || "[]")
        return WorkspaceLogic.buildHyprlandState(monitors, workspaces, clients)
    }

    function parseNiriSnapshot(text) {
        var outputs = JSON.parse(section(text, "<<<OUTPUTS>>>", "<<<WORKSPACES>>>") || "{}")
        var rawWorkspaces = JSON.parse(section(text, "<<<WORKSPACES>>>", "<<<CLIENTS>>>") || "[]")
        var rawWindows = JSON.parse(section(text, "<<<CLIENTS>>>", "<<<END>>>") || "[]")
        var monitors = []
        var activeByOutput = {}
        for (var wi = 0; wi < rawWorkspaces.length; ++wi) {
            if (rawWorkspaces[wi].is_active) activeByOutput[rawWorkspaces[wi].output || ""] = rawWorkspaces[wi].id
        }
        for (var outputName in outputs) {
            monitors.push({ name: outputName, activeWorkspace: { id: activeByOutput[outputName] }, specialWorkspace: { id: 0 } })
        }
        var workspaces = rawWorkspaces.map(function(workspace) {
            return { id: workspace.id, name: workspace.name || String(workspace.idx || workspace.id), monitor: workspace.output || "" }
        })
        var clients = rawWindows.map(function(window) {
            return {
                id: window.id,
                app_id: window.app_id || "",
                title: window.title || "",
                workspace: { id: window.workspace_id },
                is_focused: window.is_focused === true,
                urgent: window.is_urgent === true
            }
        })
        return WorkspaceLogic.buildHyprlandState(monitors, workspaces, clients)
    }

    function parseMangoSnapshot(text) {
        var payload = section(text, "<<<MANGO>>>", "<<<END>>>")
        var lines = payload.split("\n")
        var monitorsByName = {}
        var workspaces = []
        for (var i = 0; i < lines.length; ++i) {
            var parts = lines[i].trim().split(/\s+/)
            if (parts.length < 6 || parts[1] !== "tag") continue
            var monitorName = parts[0]
            var id = parseInt(parts[2])
            var stateValue = parseInt(parts[3])
            if (isNaN(id)) continue
            if (!monitorsByName[monitorName]) monitorsByName[monitorName] = { name: monitorName, activeWorkspace: { id: null }, specialWorkspace: { id: 0 } }
            if (stateValue === 1) monitorsByName[monitorName].activeWorkspace.id = id
            workspaces.push({ id: id, name: String(id), monitor: monitorName })
        }
        var monitors = Object.keys(monitorsByName).map(function(name) { return monitorsByName[name] })
        return WorkspaceLogic.buildHyprlandState(monitors, workspaces, [])
    }

    function parseSnapshot(text) {
        if (text.indexOf("<<<MONITORS>>>") !== -1) return parseHyprlandSnapshot(text)
        if (text.indexOf("<<<OUTPUTS>>>") !== -1) return parseNiriSnapshot(text)
        return parseMangoSnapshot(text)
    }

    function requestRefresh() {
        if (snapshotProc.running) {
            root.refreshPending = true
            return
        }
        root.refreshPending = false
        snapshotProc.stdoutBuffer = ""
        snapshotProc.stderrBuffer = ""
        snapshotProc.running = true
    }

    function iconFor(appId, title) {
        var id = String(appId || "").toLowerCase()
        var windowTitle = String(title || "").toLowerCase()
        if (/firefox|librewolf|floorp|cachy-browser/.test(id)) return " "
        if (/zen/.test(id)) return "󰰷 "
        if (/chromium|chrome|brave/.test(id)) return " "
        if (/kitty|konsole|ghostty|wezterm|alacritty/.test(id)) return " "
        if (/telegram/.test(id)) return " "
        if (/discord|vesktop/.test(id)) return " "
        if (/spotify/.test(id)) return " "
        if (/steam/.test(id)) return " "
        if (/code|codium/.test(id)) return "󰨞 "
        if (/codex|chatgpt|deepseek|qwen/.test(id + " " + windowTitle)) return "󰚩 "
        if (/dolphin|thunar|nemo|nautilus/.test(id)) return "󰝰 "
        if (/obs/.test(id)) return " "
        if (/vlc/.test(id)) return "󰕼 "
        if (/mpv|celluloid/.test(id)) return " "
        if (/virt-manager|virtualbox/.test(id)) return " "
        if (/antigravity|zed|jetbrains|idea/.test(id)) return "󰅩 "
        if (windowTitle === "x" || windowTitle.indexOf("— x") !== -1) return "\ueb72"
        return " "
    }

    function groupWindows(windows, shouldGroup) {
        var source = Array.isArray(windows) ? windows : []
        var result = []
        var indexes = {}
        for (var i = 0; i < source.length; ++i) {
            var window = source[i]
            var key = String(window.app_id || window.title || "unknown").toLowerCase()
            if (!shouldGroup || indexes[key] === undefined) {
                indexes[key] = result.length
                result.push({
                    icon: iconFor(window.app_id, window.title),
                    appId: window.app_id || "",
                    title: window.title || "",
                    windowId: window.id || "",
                    active: window.is_active === true,
                    urgent: window.urgent === true,
                    count: 1
                })
            } else {
                var grouped = result[indexes[key]]
                grouped.count++
                grouped.active = grouped.active || window.is_active === true
                grouped.urgent = grouped.urgent || window.urgent === true
            }
        }
        return result
    }

    function workspacesForMonitor(monitorName, config) {
        var list = WorkspaceLogic.workspacesForMonitor(root.state, monitorName, config, ScreenManager.runtimeRoleMap)
        var shouldGroup = !config || config.groupApps !== false
        for (var i = 0; i < list.length; ++i) list[i].groupedWindows = groupWindows(list[i].windows, shouldGroup)
        return list
    }

    function nextWorkspaceIndex(workspaces, currentIndex, direction, config) {
        var normalized = WorkspaceLogic.normalizeConfig(config)
        return WorkspaceLogic.nextWorkspaceIndex(
            workspaces,
            currentIndex,
            direction,
            normalized.wrapAround,
            normalized.reverseScroll
        )
    }

    function activateWorkspace(monitorName, target) {
        var command
        if (CompositorService.isHyprland) {
            command = [root.workspaceScript, String(target), String(monitorName || "")]
        } else if (CompositorService.isNiri) {
            command = ["niri", "msg", "action", "focus-workspace", String(target)]
        } else {
            command = ["mmsg", "-s", "-o", String(monitorName || ""), "-t", String(target)]
        }
        queueAction(command)
    }

    function queueAction(command) {
        if (!Array.isArray(command) || command.length === 0) return
        if (actionProc.running) {
            root.pendingAction = command
            return
        }
        actionProc.command = command
        actionProc.running = true
    }

    function focusWindow(windowId) {
        if (!windowId) return
        var command = CompositorService.isHyprland
            ? ["hyprctl", "dispatch", "focuswindow", "address:" + String(windowId)]
            : ["niri", "msg", "action", "focus-window", "--id", String(windowId)]
        queueAction(command)
    }

    Process {
        id: snapshotProc
        command: ["bash", root.snapshotScript]
        running: false
        property string stdoutBuffer: ""
        property string stderrBuffer: ""
        stdout: SplitParser { onRead: data => snapshotProc.stdoutBuffer += data + "\n" }
        stderr: SplitParser { onRead: data => snapshotProc.stderrBuffer += data + "\n" }
        onExited: exitCode => {
            if (exitCode === 0 && snapshotProc.stdoutBuffer.trim().length > 0) {
                try {
                    root.applyState(root.parseSnapshot(snapshotProc.stdoutBuffer))
                } catch (error) {
                    root.lastError = "Workspace snapshot parse failed: " + error
                    Log.warn("WorkspaceService", root.lastError)
                }
            } else {
                root.lastError = snapshotProc.stderrBuffer.trim() || ("Workspace snapshot failed (exit " + exitCode + ")")
                Log.warn("WorkspaceService", root.lastError)
            }
            snapshotProc.stdoutBuffer = ""
            snapshotProc.stderrBuffer = ""
            if (root.refreshPending) Qt.callLater(root.requestRefresh)
        }
    }

    Process {
        id: eventProc
        running: CompositorService.compositor !== "unknown" && !root.eventFallback
        command: CompositorService.isHyprland
            ? ["bash", Core.PathService.configPath("scripts/hypr_events.sh")]
            : (CompositorService.isNiri
                ? ["niri", "msg", "--json", "event-stream"]
                : ["mmsg", "-w", "-t"])
        stdout: SplitParser {
            onRead: data => {
                if (String(data || "").trim().length > 0) eventDebounce.restart()
            }
        }
        onExited: exitCode => {
            if (exitCode === 127) {
                root.eventFallback = true
                Log.warn("WorkspaceService", "Compositor event stream unavailable; using polling fallback")
            } else if (CompositorService.compositor !== "unknown") {
                eventReconnect.restart()
            }
        }
    }

    Process {
        id: actionProc
        command: []
        running: false
        property string stderrBuffer: ""
        stderr: SplitParser { onRead: data => actionProc.stderrBuffer += data + "\n" }
        onExited: exitCode => {
            if (exitCode !== 0) Log.warn("WorkspaceService", actionProc.stderrBuffer.trim() || "Workspace action failed")
            actionProc.stderrBuffer = ""
            refreshDelay.restart()
            if (root.pendingAction.length > 0) {
                var nextCommand = root.pendingAction
                root.pendingAction = []
                Qt.callLater(function() { root.queueAction(nextCommand) })
            }
        }
    }

    Timer { id: eventDebounce; interval: 60; repeat: false; onTriggered: root.requestRefresh() }
    Timer { id: refreshDelay; interval: 80; repeat: false; onTriggered: root.requestRefresh() }
    Timer {
        id: eventReconnect
        interval: 1000
        repeat: false
        onTriggered: {
            if (CompositorService.compositor !== "unknown" && !eventProc.running && !root.eventFallback) eventProc.running = true
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.eventFallback
        onTriggered: root.requestRefresh()
    }
}
