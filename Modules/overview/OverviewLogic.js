.pragma library

function stringValue(value) {
    return value === undefined || value === null ? "" : String(value);
}

function isValidWindowId(value) {
    return /^0x[0-9a-fA-F]+$/.test(stringValue(value));
}

function isValidWorkspaceTarget(value) {
    var target = stringValue(value);
    if (/^[1-9][0-9]*$/.test(target)) return true;
    return /^special:[A-Za-z0-9_.-]+$/.test(target);
}

function truncateTitle(value, maximumLength) {
    var text = stringValue(value);
    var limit = Math.max(2, Number(maximumLength) || 60);
    return text.length <= limit ? text : text.substring(0, limit - 1) + "…";
}

function workspaceTarget(workspace) {
    if (!workspace) return "";
    return stringValue(workspace.targetName || workspace.name || workspace.id);
}

function mergeWorkspaceGroups(groups) {
    var source = Array.isArray(groups) ? groups : [];
    var result = [];
    var indexes = {};

    function cloneWorkspaceRecord(workspace) {
        var sourceWorkspace = workspace || {};
        var clone = {};
        for (var key in sourceWorkspace) clone[key] = sourceWorkspace[key];
        clone.windows = Array.isArray(sourceWorkspace.windows) ? sourceWorkspace.windows.slice() : [];
        return clone;
    }

    function mergeWindowLists(first, second) {
        var windows = [];
        var seenWindows = {};
        var lists = [Array.isArray(first) ? first : [], Array.isArray(second) ? second : []];
        for (var listIndex = 0; listIndex < lists.length; ++listIndex) {
            for (var windowIndex = 0; windowIndex < lists[listIndex].length; ++windowIndex) {
                var window = lists[listIndex][windowIndex] || {};
                var windowId = stringValue(window.id);
                if (windowId && seenWindows[windowId]) continue;
                if (windowId) seenWindows[windowId] = true;
                windows.push(window);
            }
        }
        return windows;
    }

    for (var i = 0; i < source.length; ++i) {
        var group = Array.isArray(source[i]) ? source[i] : [];
        for (var j = 0; j < group.length; ++j) {
            var workspace = group[j] || {};
            var target = workspaceTarget(workspace);
            if (!target) continue;
            if (indexes[target] === undefined) {
                indexes[target] = result.length;
                result.push(cloneWorkspaceRecord(workspace));
                continue;
            }

            var index = indexes[target];
            var existing = result[index];
            var existingWindows = Array.isArray(existing.windows) ? existing.windows : [];
            var incomingWindows = Array.isArray(workspace.windows) ? workspace.windows : [];
            var preferIncoming = workspace.is_active === true
                || (existing.is_active !== true && incomingWindows.length > existingWindows.length);
            var merged = preferIncoming ? cloneWorkspaceRecord(workspace) : cloneWorkspaceRecord(existing);
            merged.windows = mergeWindowLists(existingWindows, incomingWindows);
            merged.winCount = merged.windows.length;
            merged.is_active = existing.is_active === true || workspace.is_active === true;
            merged.is_special = existing.is_special === true || workspace.is_special === true;
            result[index] = merged;
        }
    }
    return result;
}

function groupByMonitor(model, monitorOrder, focusedMonitor) {
    var safeModel = model || { regular: [], special: [] };
    var order = Array.isArray(monitorOrder) ? monitorOrder : [];
    var result = [];
    var byName = {};

    function ensure(name) {
        var monitorName = stringValue(name) || "Unassigned";
        if (byName[monitorName]) return byName[monitorName];
        var section = {
            name: monitorName,
            focused: monitorName === stringValue(focusedMonitor),
            regular: [],
            special: [],
            workspaceCount: 0,
            windowCount: 0
        };
        byName[monitorName] = section;
        result.push(section);
        return section;
    }

    for (var i = 0; i < order.length; ++i) ensure(order[i]);

    function append(workspace, special) {
        if (!workspace) return;
        var section = ensure(workspace.monitor);
        if (special) section.special.push(workspace);
        else section.regular.push(workspace);
        section.workspaceCount += 1;
        section.windowCount += Array.isArray(workspace.windows) ? workspace.windows.length : 0;
    }

    var regular = Array.isArray(safeModel.regular) ? safeModel.regular : [];
    var special = Array.isArray(safeModel.special) ? safeModel.special : [];
    for (var r = 0; r < regular.length; ++r) append(regular[r], false);
    for (var s = 0; s < special.length; ++s) append(special[s], true);
    return result;
}

function buildOverviewModel(workspaces, metadataResolver) {
    var source = Array.isArray(workspaces) ? workspaces : [];
    var result = { regular: [], special: [], windowCount: 0 };
    var seenWindows = {};
    var resolveMetadata = typeof metadataResolver === "function"
        ? metadataResolver
        : function() { return ({ appName: "Application", iconSource: "" }); };

    for (var i = 0; i < source.length; ++i) {
        var rawWorkspace = source[i] || {};
        var target = workspaceTarget(rawWorkspace);
        if (!isValidWorkspaceTarget(target)) continue;
        var windows = [];
        var rawWindows = Array.isArray(rawWorkspace.windows) ? rawWorkspace.windows : [];
        for (var j = 0; j < rawWindows.length; ++j) {
            var rawWindow = rawWindows[j] || {};
            var windowId = stringValue(rawWindow.id);
            if (!isValidWindowId(windowId) || seenWindows[windowId]) continue;
            seenWindows[windowId] = true;
            var appId = stringValue(rawWindow.app_id || rawWindow.appId);
            var metadata = resolveMetadata(appId, rawWindow.title || "") || {};
            windows.push({
                id: windowId,
                appId: appId,
                appName: stringValue(rawWindow.appName || metadata.appName || appId || "Application"),
                title: truncateTitle(rawWindow.title || metadata.appName || appId || "Application", 96),
                iconSource: stringValue(metadata.iconSource),
                active: rawWindow.is_active === true || rawWindow.active === true,
                urgent: rawWindow.urgent === true,
                sourceWorkspace: target
            });
            result.windowCount++;
        }

        var workspace = {
            id: rawWorkspace.id,
            targetName: target,
            displayName: stringValue(rawWorkspace.displayName || rawWorkspace.name || target),
            monitor: stringValue(rawWorkspace.monitor),
            active: rawWorkspace.is_active === true || rawWorkspace.active === true,
            special: rawWorkspace.is_special === true || target.indexOf("special:") === 0,
            empty: windows.length === 0,
            windowCount: windows.length,
            windows: windows
        };
        (workspace.special ? result.special : result.regular).push(workspace);
    }
    return result;
}

function canDrop(windowId, sourceWorkspace, targetWorkspace) {
    return isValidWindowId(windowId)
        && isValidWorkspaceTarget(targetWorkspace)
        && stringValue(sourceWorkspace) !== stringValue(targetWorkspace);
}

function dropTargetAt(rectangles, x, y) {
    var source = Array.isArray(rectangles) ? rectangles : [];
    var px = Number(x);
    var py = Number(y);
    if (!isFinite(px) || !isFinite(py)) return "";
    for (var i = source.length - 1; i >= 0; --i) {
        var rect = source[i] || {};
        var left = Number(rect.x) || 0;
        var top = Number(rect.y) || 0;
        var width = Math.max(0, Number(rect.width) || 0);
        var height = Math.max(0, Number(rect.height) || 0);
        if (px >= left && px <= left + width && py >= top && py <= top + height)
            return isValidWorkspaceTarget(rect.target) ? stringValue(rect.target) : "";
    }
    return "";
}
