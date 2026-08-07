import QtQuick
import QtTest
import "../Services/core/WorkspaceLogic.js" as WorkspaceLogic

TestCase {
    name: "WorkspaceLogic"

    readonly property var monitors: [
        { name: "DP-3", activeWorkspace: { id: 5 }, specialWorkspace: { id: 0 } },
        { name: "HDMI-A-1", activeWorkspace: { id: 2 }, specialWorkspace: { id: 0 } }
    ]
    readonly property var workspaces: [
        { id: 1, name: "1", monitor: "DP-3" },
        { id: 2, name: "2", monitor: "HDMI-A-1" },
        { id: 5, name: "5", monitor: "DP-3" }
    ]
    readonly property var clients: [
        { address: "0x1", class: "zen", title: "Web", workspace: { id: 2 }, focusHistoryID: 1 },
        { address: "0x2", class: "codex", title: "Codex", workspace: { id: 5 }, focusHistoryID: 0 }
    ]

    function buildState() {
        return WorkspaceLogic.buildHyprlandState(monitors, workspaces, clients)
    }

    function test_activeWorkspaceIsPerMonitor() {
        var value = buildState()
        compare(value.byMonitor["DP-3"].activeId, 5)
        compare(value.byMonitor["HDMI-A-1"].activeId, 2)
        verify(value.byMonitor["DP-3"].workspaces[1].is_active)
        verify(value.byMonitor["HDMI-A-1"].workspaces[0].is_active)
    }

    function test_roleRangesArePortIndependent() {
        var value = buildState()
        var config = { displayMode: "role", workspaceCount: 5, showEmpty: true }
        var roles = { primary: "DP-3", secondary: "HDMI-A-1" }
        var primary = WorkspaceLogic.workspacesForMonitor(value, "DP-3", config, roles)
        var secondary = WorkspaceLogic.workspacesForMonitor(value, "HDMI-A-1", config, roles)
        compare(primary.map(function(w) { return w.id }).join(","), "1,2,3,4,5")
        // Legacy active workspace 2 is preserved during migration, followed by 6-10.
        compare(secondary.map(function(w) { return w.id }).join(","), "2,6,7,8,9,10")
    }

    function test_occupiedModeHidesEmptyWorkspaces() {
        var value = buildState()
        var visible = WorkspaceLogic.workspacesForMonitor(value, "DP-3", { displayMode: "occupied" }, {})
        compare(visible.length, 1)
        compare(visible[0].id, 5)
    }

    function test_clientCountsBelongToCorrectWorkspace() {
        var value = buildState()
        compare(value.byMonitor["HDMI-A-1"].workspaces[0].winCount, 1)
        compare(value.byMonitor["DP-3"].workspaces[1].windows[0].app_id, "codex")
    }

    function test_scrollWrapAndReverse() {
        var list = [{ id: 1 }, { id: 2 }, { id: 3 }]
        compare(WorkspaceLogic.nextWorkspaceIndex(list, 2, 1, true, false), 0)
        compare(WorkspaceLogic.nextWorkspaceIndex(list, 0, -1, true, false), 2)
        compare(WorkspaceLogic.nextWorkspaceIndex(list, 1, 1, true, true), 0)
        compare(WorkspaceLogic.nextWorkspaceIndex(list, 2, 1, false, false), 2)
    }

    function test_globalModeCreatesStableEmptyRange() {
        var value = buildState()
        var visible = WorkspaceLogic.workspacesForMonitor(
            value,
            "DP-3",
            { displayMode: "global", workspaceCount: 6, showEmpty: true },
            {}
        )
        compare(visible.map(function(w) { return w.id }).join(","), "1,2,3,4,5,6")
    }

    function test_specialWorkspaceUsesPerMonitorActiveState() {
        var specialMonitors = [
            { name: "DP-3", activeWorkspace: { id: 5 }, specialWorkspace: { id: -99 } }
        ]
        var specialWorkspaces = [
            { id: 5, name: "5", monitor: "DP-3" },
            { id: -99, name: "special:magic", monitor: "DP-3" }
        ]
        var value = WorkspaceLogic.buildHyprlandState(specialMonitors, specialWorkspaces, [])
        var special = value.byMonitor["DP-3"].workspaces.filter(function(w) { return w.is_special })[0]
        verify(special.is_active)
    }
}
