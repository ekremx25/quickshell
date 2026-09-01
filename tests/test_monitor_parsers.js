#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function loadQmlJs(relativePath) {
    const filename = path.join(__dirname, "..", relativePath);
    const source = fs.readFileSync(filename, "utf8").replace(/^\.pragma library\s*$/m, "");
    const context = vm.createContext({ console });
    vm.runInContext(source, context, { filename });
    return context;
}

const parsers = loadQmlJs("Modules/bar/System/MonitorParsers.js");
const commands = loadQmlJs("Modules/bar/System/MangoMonitorCommands.js");

const outputs = parsers.parseMangoOutputs(JSON.stringify({
    monitors: [
        { name: "DP-3", x: 0, y: 0, width: 2888, height: 1625, scale: 1.33, is_hdr: true, is_vrr: true },
        { name: "HDMI-A-1", x: 2888, y: 0, width: 1920, height: 1080, scale: 1, is_hdr: false, is_vrr: false }
    ]
}));

assert.equal(outputs.length, 2);
assert.equal(outputs[0].name, "DP-3");
assert.equal(outputs[0].res, "3840x2160");
assert.equal(outputs[0].scale, "1.33");
assert.equal(outputs[0].hdr, true);
assert.equal(outputs[0].vrr, 1);
assert.deepEqual(JSON.parse(JSON.stringify(outputs[0].modes)), [
    { res: "3840x2160", hz: "60.000", current: true }
]);
assert.equal(outputs[1].res, "1920x1080");
assert.equal(outputs[1].posX, 2888);

const steps = commands.buildOutputSteps(
    "DP-3", "3840x2160", "160.00", 0, 0, "1.33",
    { vrr: 1, hdr: true }, "/config/scripts/mango_monitor_apply.sh"
);
assert.deepEqual(JSON.parse(JSON.stringify(steps)), [{
    argv: [
        "/config/scripts/mango_monitor_apply.sh", "set", "DP-3", "3840x2160",
        "160.00", "0", "0", "1.33", "1", "1"
    ]
}]);

assert.equal(commands.shouldApplyOutput(true, false), true);
assert.equal(commands.shouldApplyOutput(false, true), true);
assert.equal(commands.shouldApplyOutput(false, false), false);

console.log("Monitor parser and Mango command tests passed");
