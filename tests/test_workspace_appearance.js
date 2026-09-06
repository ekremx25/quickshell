const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
function load(file) {
    const scope = vm.createContext({});
    vm.runInContext(fs.readFileSync(path.join(__dirname, "..", file), "utf8").replace(/^\.pragma library\s*/m, ""), scope);
    return scope;
}
const appearance = load("Modules/bar/Workspaces/WorkspaceAppearance.js");
for (const transparent of [true, false]) {
    for (const style of ["underline", "overline", "pipe", "dot"]) {
        const result = appearance.resolve(style, transparent, true);
        assert.equal(result.indicator, style, `${style} remains distinct with transparency=${transparent}`);
        assert.equal(result.fill, !transparent);
    }
    const outline = appearance.resolve("outline", transparent, true);
    assert.equal(outline.fill, false);
    assert.equal(outline.borderWidth, 2);
    for (const style of ["square", "circle"]) {
        assert.equal(appearance.resolve(style, transparent, true).borderWidth, 2);
    }
    assert.notEqual(appearance.resolve("square", transparent, true).radius, appearance.resolve("circle", transparent, true).radius);
}
const defaults = load("Modules/bar/BarDefaults.js").createWorkspacesConfig();
const logicDefaults = load("Services/core/WorkspaceLogic.js").normalizeConfig({});
for (const key of Object.keys(logicDefaults)) assert.equal(logicDefaults[key], defaults[key], `default ${key}`);
const apps = load("Modules/bar/Dock/AppService.js");
assert.equal(apps.getIcon("zen", {}, {}, {}), "application-x-executable", "startup avoids unresolved class name");
assert.equal(apps.getIcon("zen", {zen:"zen-browser"}, {zen:"zen"}, {}), "zen-browser");
assert.equal(apps.getIcon("affinity.exe", {"affinity.exe":"/icons/Affinity.svg"}, {}, {}), "/icons/Affinity.svg");
assert.equal(apps.getIcon("affinity.exe", {affinity:"/icons/Affinity.svg"}, {affinity:"Affinity"}, {}), "/icons/Affinity.svg");
assert.equal(apps.getIcon("unknown.exe", {zen:"zen-browser"}, {}, {}), "application-x-executable");
console.log("Workspace appearance, shared defaults and icon lookup tests passed");
