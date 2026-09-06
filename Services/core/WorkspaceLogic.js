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
        workspaceCount: clampInt(source.workspaceCount, 1, 20, 4),
        showEmpty: source.showEmpty !== false,
        showSpecial: source.showSpecial !== false,
        wrapAround: source.wrapAround !== false,
        reverseScroll: source.reverseScroll === true,
        maxIcons: clampInt(source.maxIcons, 1, 12, 3)
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
    var leftOrder = left.displayOrder !== undefined ? Number(left.displayOrder) : Number(left.sortOrder);
    var rightOrder = right.displayOrder !== undefined ? Number(right.displayOrder) : Number(right.sortOrder);
    if (!isNaN(leftOrder) && !isNaN(rightOrder) && leftOrder !== rightOrder) return leftOrder - rightOrder;
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

// Niri workspace IDs are opaque runtime identifiers. The user-visible index is
// `idx`, and every monitor owns an independent workspace list. Keep the opaque
// ID for matching windows, but use the local index for ordering and activation.
function buildNiriState(outputs, workspaces, windows) {
    var state = { monitorOrder: [], byMonitor: {}, global: [], localIndexed: true };
    var outputMap = outputs && typeof outputs === "object" ? outputs : {};
    var workspaceList = Array.isArray(workspaces) ? workspaces : [];
    var windowList = Array.isArray(windows) ? windows : [];

    for (var outputName in outputMap) {
        state.monitorOrder.push(outputName);
        state.byMonitor[outputName] = { activeId: null, specialId: null, workspaces: [] };
    }

    var workspaceById = {};
    for (var wi = 0; wi < workspaceList.length; ++wi) {
        var raw = workspaceList[wi] || {};
        var monitorName = String(raw.output || "");
        if (!state.byMonitor[monitorName]) {
            state.monitorOrder.push(monitorName);
            state.byMonitor[monitorName] = { activeId: null, specialId: null, workspaces: [] };
        }

        var localIndex = parseInt(raw.idx);
        if (isNaN(localIndex) || localIndex < 1) localIndex = state.byMonitor[monitorName].workspaces.length + 1;
        var entry = {
            id: raw.id,
            idx: localIndex,
            sortOrder: localIndex,
            name: raw.name !== undefined && raw.name !== null ? String(raw.name) : String(localIndex),
            monitor: monitorName,
            is_active: raw.is_active === true,
            is_special: false,
            winCount: 0,
            windows: [],
            groupedWindows: []
        };

        if (entry.is_active) state.byMonitor[monitorName].activeId = raw.id;
        workspaceById[String(raw.id)] = entry;
        state.byMonitor[monitorName].workspaces.push(entry);
        state.global.push(entry);
    }

    for (var windowIndex = 0; windowIndex < windowList.length; ++windowIndex) {
        var rawWindow = windowList[windowIndex] || {};
        var parent = workspaceById[String(rawWindow.workspace_id)];
        if (!parent) continue;
        parent.windows.push({
            id: rawWindow.id || "",
            app_id: rawWindow.app_id || "",
            title: rawWindow.title || "",
            is_active: rawWindow.is_focused === true,
            urgent: rawWindow.is_urgent === true
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
        sortOrder: workspace.sortOrder,
        displayOrder: workspace.displayOrder,
        name: workspace.name,
        targetName: workspace.targetName,
        displayName: workspace.displayName,
        localTag: workspace.localTag,
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
    var localRoleMode = normalized.displayMode === "role"
        && (safeState.tagBased === true || safeState.localIndexed === true);

    function add(workspace) {
        if (!workspace) return;
        if (workspace.is_special && !normalized.showSpecial) return;
        var key = String(workspace.id);
        if (seen[key]) return;
        if ((safeState.tagBased === true || safeState.localIndexed === true)
                && !normalized.showEmpty && !workspace.is_active && (workspace.winCount || 0) === 0) return;
        if (normalized.displayMode === "occupied" && !workspace.is_active && (workspace.winCount || 0) === 0) return;
        seen[key] = true;
        result.push(cloneWorkspace(workspace));
    }

    if (localRoleMode) {
        // Mango and Niri number workspaces locally on every monitor. Present a
        // global-looking role range while retaining the local activation target.
        var tagRange = rangeForMonitor(monitorName, normalized, roleMap, safeState.monitorOrder || []);
        var localTags = {};
        var monitorTags = monitorState.workspaces || [];
        for (var ti = 0; ti < monitorTags.length; ++ti) {
            var slot = safeState.localIndexed === true ? monitorTags[ti].idx : monitorTags[ti].id;
            localTags[String(slot)] = monitorTags[ti];
        }

        for (var localId = 1; localId <= normalized.workspaceCount; ++localId) {
            var localWorkspace = localTags[String(localId)];
            if (!localWorkspace) {
                var emptyId = safeState.localIndexed === true ? monitorName + "::" + localId : localId;
                localWorkspace = emptyWorkspace(emptyId, monitorName);
                localWorkspace.idx = localId;
                localWorkspace.sortOrder = localId;
                localWorkspace.name = String(localId);
            }
            var decorated = cloneWorkspace(localWorkspace);
            decorated.localTag = localId;
            decorated.targetName = String(safeState.localIndexed === true ? localId : (localWorkspace.name || localId));
            decorated.displayName = String(tagRange.start + localId - 1);
            decorated.displayOrder = tagRange.start + localId - 1;
            add(decorated);
        }

        // Never hide an active or occupied tag outside the configured role
        // range. Prefix it with the monitor role so its label stays unambiguous.
        for (var extraIndex = 0; extraIndex < monitorTags.length; ++extraIndex) {
            var extra = monitorTags[extraIndex];
            var extraId = parseInt(safeState.localIndexed === true ? extra.idx : extra.id);
            if (extraId >= 1 && extraId <= normalized.workspaceCount) continue;
            if (!extra.is_active && (extra.winCount || 0) === 0) continue;
            var extraDecorated = cloneWorkspace(extra);
            extraDecorated.localTag = extraId;
            extraDecorated.targetName = String(safeState.localIndexed === true ? extraId : (extra.name || extra.id));
            extraDecorated.displayName = String(tagRange.role || "display").charAt(0).toUpperCase() + String(extraId);
            extraDecorated.displayOrder = tagRange.end + Math.max(1, extraId);
            add(extraDecorated);
        }
    } else {
        for (var i = 0; i < source.length; ++i) add(source[i]);
    }

    if (normalized.displayMode === "global" && normalized.showEmpty) {
        for (var globalId = 1; globalId <= normalized.workspaceCount; ++globalId) {
            if (!seen[String(globalId)]) add(emptyWorkspace(globalId, monitorName));
        }
    }

    // Numeric workspace IDs can be filled directly only when they are global.
    // Mango role mode above keeps its local IDs and remaps display labels only.
    if (normalized.displayMode === "role"
            && safeState.tagBased !== true
            && safeState.localIndexed !== true) {
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
