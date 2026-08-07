// Pure workspace model helpers. Kept independent from QML/Process so the
// multi-monitor rules can be covered by deterministic unit tests.

function clampInt(value, minimum, maximum, fallback) {
    var parsed = parseInt(value);
    if (isNaN(parsed)) parsed = fallback;
    return Math.max(minimum, Math.min(maximum, parsed));
}

function normalizeConfig(config) {
    var source = config || {};
    var mode = ["role", "occupied", "global"].indexOf(source.displayMode) !== -1
        ? source.displayMode
        : "role";
    return {
        displayMode: mode,
        workspaceCount: clampInt(source.workspaceCount, 1, 20, 5),
        showEmpty: source.showEmpty !== false,
        showSpecial: source.showSpecial === true,
        wrapAround: source.wrapAround !== false,
        reverseScroll: source.reverseScroll === true,
        maxIcons: clampInt(source.maxIcons, 1, 12, 4)
    };
}

function monitorRole(monitorName, roleMap, monitorOrder) {
    var roles = ["primary", "secondary", "tertiary"];
    var map = roleMap || {};
    for (var i = 0; i < roles.length; ++i) {
        if (map[roles[i]] === monitorName) return roles[i];
    }
    var index = (monitorOrder || []).indexOf(monitorName);
    return index === 0 ? "primary" : (index === 1 ? "secondary" : (index === 2 ? "tertiary" : "display-" + (index + 1)));
}

function roleIndex(role) {
    if (role === "primary") return 0;
    if (role === "secondary") return 1;
    if (role === "tertiary") return 2;
    var match = String(role || "").match(/^display-(\d+)$/);
    return match ? Math.max(0, parseInt(match[1]) - 1) : 0;
}

function rangeForMonitor(monitorName, config, roleMap, monitorOrder) {
    var normalized = normalizeConfig(config);
    var role = monitorRole(monitorName, roleMap, monitorOrder);
    var start = roleIndex(role) * normalized.workspaceCount + 1;
    return { role: role, start: start, end: start + normalized.workspaceCount - 1 };
}

function emptyWorkspace(id, monitorName) {
    return {
        id: id,
        idx: id,
        name: String(id),
        monitor: monitorName || "",
        is_active: false,
        is_special: false,
        winCount: 0,
        windows: [],
        groupedWindows: []
    };
}

function workspaceSort(left, right) {
    if (!!left.is_special !== !!right.is_special) return left.is_special ? 1 : -1;
    var leftNum = Number(left.id);
    var rightNum = Number(right.id);
    if (!isNaN(leftNum) && !isNaN(rightNum)) return leftNum - rightNum;
    return String(left.name || "").localeCompare(String(right.name || ""));
}

function buildHyprlandState(monitors, workspaces, clients) {
    var state = { monitorOrder: [], byMonitor: {}, global: [] };
    var monitorList = Array.isArray(monitors) ? monitors : [];
    var workspaceList = Array.isArray(workspaces) ? workspaces : [];
    var clientList = Array.isArray(clients) ? clients : [];

    for (var mi = 0; mi < monitorList.length; ++mi) {
        var monitor = monitorList[mi] || {};
        var monitorName = String(monitor.name || "");
        if (monitorName.length === 0) continue;
        state.monitorOrder.push(monitorName);
        state.byMonitor[monitorName] = {
            activeId: monitor.activeWorkspace ? monitor.activeWorkspace.id : null,
            specialId: monitor.specialWorkspace ? monitor.specialWorkspace.id : null,
            workspaces: []
        };
    }

    var workspaceById = {};
    for (var wi = 0; wi < workspaceList.length; ++wi) {
        var raw = workspaceList[wi] || {};
        var name = raw.name !== undefined && raw.name !== null ? String(raw.name) : String(raw.id);
        var monitorForWorkspace = String(raw.monitor || "");
        var special = Number(raw.id) < 0 || name.indexOf("special:") === 0;
        var monitorState = state.byMonitor[monitorForWorkspace];
        var regularActive = !!(monitorState && String(monitorState.activeId) === String(raw.id));
        var specialActive = !!(special && monitorState && String(monitorState.specialId) === String(raw.id));
        var entry = {
            id: raw.id,
            idx: raw.id,
            name: name,
            monitor: monitorForWorkspace,
            is_active: regularActive || specialActive,
            is_special: special,
            winCount: 0,
            windows: [],
            groupedWindows: []
        };
        workspaceById[String(raw.id)] = entry;
        state.global.push(entry);
        if (!state.byMonitor[monitorForWorkspace]) {
            state.monitorOrder.push(monitorForWorkspace);
            state.byMonitor[monitorForWorkspace] = { activeId: null, specialId: null, workspaces: [] };
        }
        state.byMonitor[monitorForWorkspace].workspaces.push(entry);
    }

    for (var ci = 0; ci < clientList.length; ++ci) {
        var client = clientList[ci] || {};
        if (!client.workspace) continue;
        var parent = workspaceById[String(client.workspace.id)];
        if (!parent) continue;
        parent.windows.push({
            id: client.address || client.id || "",
            app_id: client.class || client.initialClass || client.app_id || "",
            title: client.title || "",
            is_active: client.focusHistoryID === 0 || client.is_focused === true,
            urgent: client.urgent === true
        });
        parent.winCount++;
    }

    state.global.sort(workspaceSort);
    for (var monitorKey in state.byMonitor) state.byMonitor[monitorKey].workspaces.sort(workspaceSort);
    return state;
}

function cloneWorkspace(workspace) {
    return {
        id: workspace.id,
        idx: workspace.idx,
        name: workspace.name,
        monitor: workspace.monitor,
        is_active: workspace.is_active,
        is_special: workspace.is_special,
        winCount: workspace.winCount || 0,
        windows: (workspace.windows || []).slice(),
        groupedWindows: (workspace.groupedWindows || []).slice()
    };
}

function workspacesForMonitor(state, monitorName, config, roleMap) {
    var safeState = state || { monitorOrder: [], byMonitor: {}, global: [] };
    var normalized = normalizeConfig(config);
    var monitorState = safeState.byMonitor && safeState.byMonitor[monitorName]
        ? safeState.byMonitor[monitorName]
        : { activeId: null, workspaces: [] };
    var source = normalized.displayMode === "global"
        ? (safeState.global || [])
        : (monitorState.workspaces || []);
    var result = [];
    var seen = {};

    function add(workspace) {
        if (!workspace) return;
        if (workspace.is_special && !normalized.showSpecial) return;
        var key = String(workspace.id);
        if (seen[key]) return;
        if (normalized.displayMode === "occupied" && !workspace.is_active && (workspace.winCount || 0) === 0) return;
        seen[key] = true;
        result.push(cloneWorkspace(workspace));
    }

    for (var i = 0; i < source.length; ++i) add(source[i]);

    if (normalized.displayMode === "global" && normalized.showEmpty) {
        for (var globalId = 1; globalId <= normalized.workspaceCount; ++globalId) {
            if (!seen[String(globalId)]) add(emptyWorkspace(globalId, monitorName));
        }
    }

    if (normalized.displayMode === "role") {
        var range = rangeForMonitor(monitorName, normalized, roleMap, safeState.monitorOrder || []);
        if (normalized.showEmpty) {
            for (var id = range.start; id <= range.end; ++id) {
                if (!seen[String(id)]) add(emptyWorkspace(id, monitorName));
            }
        }
        // Preserve occupied/active legacy workspaces outside the new role range
        // so switching modes never makes a currently used workspace disappear.
        for (var legacy = 0; legacy < (monitorState.workspaces || []).length; ++legacy) {
            var existing = monitorState.workspaces[legacy];
            if (existing.is_active || existing.winCount > 0) add(existing);
        }
    }

    result.sort(workspaceSort);
    return result;
}

function nextWorkspaceIndex(workspaces, currentIndex, direction, wrapAround, reverseScroll) {
    var list = Array.isArray(workspaces) ? workspaces : [];
    if (list.length === 0) return -1;
    var step = direction > 0 ? 1 : -1;
    if (reverseScroll) step *= -1;
    var current = currentIndex >= 0 && currentIndex < list.length ? currentIndex : 0;
    var next = current + step;
    if (wrapAround) return (next + list.length) % list.length;
    return Math.max(0, Math.min(list.length - 1, next));
}
