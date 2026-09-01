// Pure adapters for MangoWM 0.16+ JSON IPC responses.
// Keeping the translation here makes the QML services small and allows the
// compositor-specific model to be tested without a running Wayland session.

function payloadArray(payload, key) {
    if (Array.isArray(payload)) return payload;
    if (payload && Array.isArray(payload[key])) return payload[key];
    return [];
}

function integer(value, fallback) {
    var parsed = parseInt(value);
    return isNaN(parsed) ? fallback : parsed;
}

function normalizeClients(payload) {
    var clients = payloadArray(payload, "clients");
    var normalized = [];
    for (var i = 0; i < clients.length; ++i) {
        var client = clients[i] || {};
        normalized.push({
            id: client.id !== undefined && client.id !== null ? client.id : "",
            app_id: client.appid || client.app_id || "",
            title: client.title || "",
            monitor: client.monitor || "",
            tags: Array.isArray(client.tags) ? client.tags.slice() : [],
            is_focused: client.is_focused === true,
            is_visible: client.is_visible === true,
            is_minimized: client.is_minimized === true,
            urgent: client.is_urgent === true || client.urgent === true
        });
    }
    return normalized;
}

function normalizeMonitors(payload) {
    var monitors = payloadArray(payload, "monitors");
    var normalized = [];
    for (var i = 0; i < monitors.length; ++i) {
        var monitor = monitors[i] || {};
        var name = String(monitor.name || "");
        if (name === "") continue;
        normalized.push({
            name: name,
            make: monitor.make || "",
            model: monitor.model || "",
            width: integer(monitor.width, 0),
            height: integer(monitor.height, 0),
            refreshRate: monitor.refresh_rate !== undefined
                ? String(monitor.refresh_rate)
                : "0",
            scale: Number(monitor.scale) || 1.0,
            active: monitor.active === true,
            activeTags: Array.isArray(monitor.active_tags) ? monitor.active_tags.slice() : []
        });
    }
    return normalized;
}

function buildWorkspaceState(tagsPayload, clientsPayload) {
    var state = { monitorOrder: [], byMonitor: {}, global: [], tagBased: true };
    var monitorTags = payloadArray(tagsPayload, "all_tags");
    var hasClientSnapshot = !!(clientsPayload && Array.isArray(clientsPayload.clients));
    var clients = normalizeClients(clientsPayload);
    var workspaceByMonitor = {};

    for (var mi = 0; mi < monitorTags.length; ++mi) {
        var monitorEntry = monitorTags[mi] || {};
        var monitorName = String(monitorEntry.monitor || "");
        if (monitorName === "") continue;
        if (!state.byMonitor[monitorName]) {
            state.monitorOrder.push(monitorName);
            state.byMonitor[monitorName] = { activeId: null, activeIds: [], specialId: null, workspaces: [] };
            workspaceByMonitor[monitorName] = {};
        }

        var tags = Array.isArray(monitorEntry.tags) ? monitorEntry.tags : [];
        for (var ti = 0; ti < tags.length; ++ti) {
            var rawTag = tags[ti] || {};
            var tagId = integer(rawTag.index !== undefined ? rawTag.index : rawTag.tag_index, -1);
            if (tagId < 1) continue;
            var active = rawTag.is_active === true;
            var workspace = {
                id: tagId,
                idx: tagId,
                name: String(tagId),
                monitor: monitorName,
                is_active: active,
                is_special: false,
                winCount: hasClientSnapshot ? 0 : integer(rawTag.client_count, 0),
                windows: [],
                groupedWindows: []
            };
            if (active) {
                state.byMonitor[monitorName].activeIds.push(tagId);
                if (state.byMonitor[monitorName].activeId === null) state.byMonitor[monitorName].activeId = tagId;
            }
            workspaceByMonitor[monitorName][String(tagId)] = workspace;
            state.byMonitor[monitorName].workspaces.push(workspace);
            state.global.push(workspace);
        }
    }

    for (var ci = 0; ci < clients.length; ++ci) {
        var client = clients[ci];
        var monitorMap = workspaceByMonitor[client.monitor];
        if (!monitorMap) continue;
        for (var cti = 0; cti < client.tags.length; ++cti) {
            var parent = monitorMap[String(client.tags[cti])];
            if (!parent) continue;
            parent.windows.push({
                id: client.id,
                app_id: client.app_id,
                title: client.title,
                is_active: client.is_focused,
                urgent: client.urgent
            });
            parent.winCount++;
        }
    }

    function sortById(left, right) { return Number(left.id) - Number(right.id); }
    state.global.sort(function(left, right) {
        var monitorDelta = state.monitorOrder.indexOf(left.monitor) - state.monitorOrder.indexOf(right.monitor);
        return monitorDelta !== 0 ? monitorDelta : sortById(left, right);
    });
    for (var monitorKey in state.byMonitor) state.byMonitor[monitorKey].workspaces.sort(sortById);
    return state;
}
