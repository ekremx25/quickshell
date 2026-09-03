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

const workspaceLogic = loadQmlJs("Services/core/WorkspaceLogic.js");

const outputs = { "DP-3": {}, "HDMI-A-1": {} };
const workspaces = [
    { id: 16, idx: 3, output: "HDMI-A-1", is_active: false },
    { id: 15, idx: 2, output: "DP-3", is_active: true },
    { id: 2, idx: 1, output: "HDMI-A-1", is_active: true },
    { id: 1, idx: 1, output: "DP-3", is_active: false },
    { id: 11, idx: 2, output: "HDMI-A-1", is_active: false },
    { id: 17, idx: 3, output: "DP-3", is_active: false }
];
const windows = [
    { id: 4, app_id: "zen", title: "YouTube", workspace_id: 1, is_focused: false },
    { id: 47, app_id: "chatgpt", title: "ChatGPT", workspace_id: 15, is_focused: false },
    { id: 39, app_id: "zen", title: "Zen", workspace_id: 2, is_focused: true },
    { id: 46, app_id: "org.telegram.desktop", title: "Telegram", workspace_id: 11, is_focused: false }
];

const state = workspaceLogic.buildNiriState(outputs, workspaces, windows);
assert.equal(state.localIndexed, true);
assert.equal(state.byMonitor["DP-3"].activeId, 15);
assert.equal(state.byMonitor["HDMI-A-1"].activeId, 2);
assert.equal(state.byMonitor["DP-3"].workspaces.map(item => item.idx).join(","), "1,2,3");
assert.equal(state.byMonitor["DP-3"].workspaces[1].windows[0].app_id, "chatgpt");
assert.equal(state.byMonitor["HDMI-A-1"].workspaces[1].windows[0].app_id, "org.telegram.desktop");

const roleConfig = {
    displayMode: "role",
    workspaceCount: 6,
    showEmpty: true,
    showSpecial: false,
    wrapAround: true,
    reverseScroll: false
};
const roleMap = { primary: "DP-3", secondary: "HDMI-A-1" };
const primary = workspaceLogic.workspacesForMonitor(state, "DP-3", roleConfig, roleMap);
const secondary = workspaceLogic.workspacesForMonitor(state, "HDMI-A-1", roleConfig, roleMap);

assert.equal(primary.map(item => item.displayName).join(","), "1,2,3,4,5,6");
assert.equal(primary.map(item => item.targetName).join(","), "1,2,3,4,5,6");
assert.equal(primary[1].id, 15);
assert.equal(primary[1].is_active, true);
assert.equal(secondary.map(item => item.displayName).join(","), "7,8,9,10,11,12");
assert.equal(secondary.map(item => item.targetName).join(","), "1,2,3,4,5,6");
assert.equal(secondary[0].id, 2);
assert.equal(secondary[0].is_active, true);
assert.notEqual(primary[3].id, secondary[3].id);

const occupiedConfig = Object.assign({}, roleConfig, { displayMode: "occupied", showEmpty: false });
const occupiedPrimary = workspaceLogic.workspacesForMonitor(state, "DP-3", occupiedConfig, roleMap);
assert.equal(occupiedPrimary.map(item => item.idx).join(","), "1,2");

console.log("Niri workspace adapter tests passed");
