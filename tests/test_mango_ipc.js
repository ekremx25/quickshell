#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function loadQmlJs(relativePath) {
    const filename = path.join(__dirname, "..", relativePath);
    const context = vm.createContext({ console });
    vm.runInContext(fs.readFileSync(filename, "utf8"), context, { filename });
    return context;
}

const mango = loadQmlJs("Services/core/MangoIpc.js");
const workspaceLogic = loadQmlJs("Services/core/WorkspaceLogic.js");

const tagsPayload = {
    all_tags: [
        {
            monitor: "DP-3",
            tags: [
                { index: 1, is_active: true, is_urgent: false, client_count: 1 },
                { index: 2, is_active: false, is_urgent: false, client_count: 1 },
                { index: 3, is_active: false, is_urgent: false, client_count: 0 }
            ]
        },
        {
            monitor: "HDMI-A-1",
            tags: [
                { index: 1, is_active: false, is_urgent: false, client_count: 0 },
                { index: 2, is_active: true, is_urgent: false, client_count: 1 }
            ]
        }
    ]
};

const clientsPayload = {
    clients: [
        {
            id: 41,
            appid: "kitty",
            title: "Terminal",
            monitor: "DP-3",
            tags: [1, 2],
            is_focused: true,
            is_visible: true,
            is_urgent: false
        },
        {
            id: 73,
            appid: "firefox",
            title: "Mango IPC",
            monitor: "HDMI-A-1",
            tags: [2],
            is_focused: false,
            is_visible: true,
            is_urgent: true
        }
    ]
};

const clients = mango.normalizeClients(clientsPayload);
assert.equal(clients.length, 2);
assert.equal(clients[0].app_id, "kitty");
assert.equal(clients[1].urgent, true);

const state = mango.buildWorkspaceState(tagsPayload, clientsPayload);
assert.equal(state.tagBased, true);
assert.equal(state.byMonitor["DP-3"].activeId, 1);
assert.equal(state.byMonitor["HDMI-A-1"].activeId, 2);
assert.equal(state.byMonitor["DP-3"].workspaces[0].windows[0].id, 41);
assert.equal(state.byMonitor["DP-3"].workspaces[1].windows[0].app_id, "kitty");
assert.equal(state.byMonitor["HDMI-A-1"].workspaces[1].windows[0].urgent, true);

// Mango keeps activation targets local to each monitor, while role mode shows
// a distinct visual range per monitor (primary 1-5, secondary 6-10).
const roleConfig = {
    displayMode: "role",
    workspaceCount: 5,
    showEmpty: true,
    showSpecial: false,
    wrapAround: true,
    reverseScroll: false
};
const roleMap = { primary: "DP-3", secondary: "HDMI-A-1" };
const hdmiTags = workspaceLogic.workspacesForMonitor(state, "HDMI-A-1", roleConfig, roleMap);
assert.equal(hdmiTags.length, 5);
assert.equal(hdmiTags.map(item => item.displayName).join(","), "6,7,8,9,10");
assert.equal(hdmiTags.map(item => item.targetName).join(","), "1,2,3,4,5");
assert.equal(hdmiTags[1].id, 2);
assert.equal(hdmiTags[1].is_active, true);

const primaryTags = workspaceLogic.workspacesForMonitor(state, "DP-3", roleConfig, roleMap);
assert.equal(primaryTags.map(item => item.displayName).join(","), "1,2,3,4,5");
assert.equal(primaryTags.map(item => item.targetName).join(","), "1,2,3,4,5");

const hiddenEmptyConfig = Object.assign({}, roleConfig, { showEmpty: false });
const dpOccupied = workspaceLogic.workspacesForMonitor(state, "DP-3", hiddenEmptyConfig, roleMap);
assert.equal(dpOccupied.map(item => item.id).join(","), "1,2");

const monitors = mango.normalizeMonitors({
    monitors: [{ name: "DP-3", width: 2888, height: 1625, scale: 1.33, active_tags: [1] }]
});
assert.equal(monitors[0].name, "DP-3");
assert.equal(monitors[0].scale, 1.33);

console.log("Mango IPC adapter tests passed");
