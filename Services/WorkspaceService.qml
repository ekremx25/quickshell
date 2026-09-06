pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./core" as Core
import "./core/WorkspaceLogic.js" as WorkspaceLogic
import "./core/MangoIpc.js" as MangoIpc
import "./core/Log.js" as Log
import "../Modules/bar/Dock/AppService.js" as AppService

Singleton {
    id: root

    property var state: ({ monitorOrder: [], byMonitor: {}, global: [] })
    property int revision: 0
    property bool available: false
    property bool refreshPending: false
    property bool eventFallback: false
    property bool mangoClientEventFallback: false
    property string lastError: ""
    property var pendingAction: []
    property var desktopIcons: ({})
    property var desktopCommands: ({})
    property var desktopEntries: ({})

    readonly property string snapshotScript: Core.PathService.configPath("scripts/workspace_snapshot.sh")
    readonly property string workspaceScript: Core.PathService.configPath("scripts/hypr_workspace_apply.sh")
    readonly property string niriWorkspaceScript: Core.PathService.configPath("scripts/niri_workspace_apply.sh")
    readonly property string desktopIconScript: Core.PathService.configPath("scripts/desktop_icons.sh")

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
        return WorkspaceLogic.buildNiriState(outputs, rawWorkspaces, rawWindows)
    }

    function parseMangoSnapshot(text) {
        var tags = JSON.parse(section(text, "<<<MANGO_TAGS>>>", "<<<MANGO_CLIENTS>>>") || "{\"all_tags\":[]}")
        var clients = JSON.parse(section(text, "<<<MANGO_CLIENTS>>>", "<<<END>>>") || "{\"clients\":[]}")
        return MangoIpc.buildWorkspaceState(tags, clients)
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

    function parseDesktopMetadata(raw) {
        var parts = []
        var depth = 0
        var startIndex = -1
        for (var index = 0; index < raw.length; ++index) {
            if (raw[index] === "{") {
                if (depth === 0) startIndex = index
                depth++
            } else if (raw[index] === "}") {
                depth--
                if (depth === 0 && startIndex >= 0) {
                    parts.push(raw.substring(startIndex, index + 1))
                    startIndex = -1
                }
            }
        }
        return {
            icons: parts.length > 0 ? JSON.parse(parts[0]) : {},
            commands: parts.length > 1 ? JSON.parse(parts[1]) : {},
            entries: parts.length > 2 ? JSON.parse(parts[2]) : {}
        }
    }

    function iconSourceFor(appId) {
        // Use the glyph until metadata is ready; the revision below rebuilds
        // workspace icons as soon as the desktop lookup has completed.
        if (Object.keys(root.desktopIcons).length === 0) return ""
        var iconName = AppService.getIcon(
            appId || "",
            root.desktopIcons,
            root.desktopEntries,
            root.desktopCommands
        )
        iconName = AppService.resolveThemedIconName(iconName)
        if (!iconName) return ""
        if (String(iconName).indexOf("/") === 0) return "file://" + iconName
        return "image://icon/" + iconName
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
                    iconSource: iconSourceFor(window.app_id),
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
            command = [root.niriWorkspaceScript, String(target), String(monitorName || "")]
        } else if (CompositorService.isMango) {
            command = monitorName
                ? ["mmsg", "dispatch", "viewcrossmon," + String(target) + "," + String(monitorName)]
                : ["mmsg", "dispatch", "view," + String(target)]
        } else {
            return
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
        var command
        if (CompositorService.isHyprland) {
            command = ["hyprctl", "dispatch", "focuswindow", "address:" + String(windowId)]
        } else if (CompositorService.isNiri) {
            command = ["niri", "msg", "action", "focus-window", "--id", String(windowId)]
        } else if (CompositorService.isMango) {
            command = ["mmsg", "dispatch", "focusid", "client," + String(windowId)]
        } else {
            return
        }
        queueAction(command)
    }

    Process {
        id: desktopIconProc
        command: ["bash", root.desktopIconScript]
        running: false
        property string outputBuffer: ""
        stdout: SplitParser { onRead: data => desktopIconProc.outputBuffer += data + "\n" }
        onExited: exitCode => {
            if (exitCode === 0 && desktopIconProc.outputBuffer.trim() !== "") {
                try {
                    var metadata = root.parseDesktopMetadata(desktopIconProc.outputBuffer)
                    root.desktopIcons = metadata.icons
                    root.desktopCommands = metadata.commands
                    root.desktopEntries = metadata.entries
                    root.revision++
                } catch (error) {
                    Log.warn("WorkspaceService", "Desktop icon metadata parse failed: " + error)
                }
            }
            desktopIconProc.outputBuffer = ""
        }
        Component.onCompleted: running = true
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
                : ["mmsg", "watch", "all-tags"])
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

    // Mango exposes client changes on a separate JSON watch stream. Tag and
    // client events both rebuild the combined workspace snapshot.
    Process {
        id: mangoClientEventProc
        running: CompositorService.isMango && !root.mangoClientEventFallback
        command: ["mmsg", "watch", "all-clients"]
        stdout: SplitParser {
            onRead: data => {
                if (String(data || "").trim().length > 0) eventDebounce.restart()
            }
        }
        onExited: exitCode => {
            if (!CompositorService.isMango) return
            if (exitCode === 127) {
                root.mangoClientEventFallback = true
                Log.warn("WorkspaceService", "Mango client event stream unavailable; using polling fallback")
            } else {
                mangoClientEventReconnect.restart()
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
        id: mangoClientEventReconnect
        interval: 1000
        repeat: false
        onTriggered: {
            if (CompositorService.isMango && !mangoClientEventProc.running && !root.mangoClientEventFallback)
                mangoClientEventProc.running = true
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.eventFallback || (CompositorService.isMango && root.mangoClientEventFallback)
        onTriggered: root.requestRefresh()
    }
}
