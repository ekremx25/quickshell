import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Services"
import "../../../Services/core" as Core
import "../../../Services/core/Log.js" as Log
import "HyprMonitorCommands.js"  as HyprMonitorCommands
import "NiriMonitorCommands.js"  as NiriMonitorCommands
import "MangoMonitorCommands.js" as MangoMonitorCommands
import "MonitorParsers.js"       as MonitorParsers

Item {
    id: backend
    visible: false
    width: 0
    height: 0

    property var outputs: []
    property int selectedIdx: 0
    property var selectedOutput: outputs.length > selectedIdx ? outputs[selectedIdx] : null
    property var savedConfig: ({})
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")
    readonly property string configDir: configHome + "/quickshell"
    readonly property string monitorConfigPath: configDir + "/monitor_config.json"
    property bool _pendingMangoReload: false
    property var _applyQueue: []
    property int _applyStep: 0
    readonly property string niriScriptPath: configDir + "/Modules/bar/System/niri_apply.py"
    readonly property string mangoConfigPath: homeDir + "/.config/mango/config.conf"

    // Color mode lists are canonical in HyprMonitorCommands.js; kept here for UI binding.
    readonly property var riskyColorModes: HyprMonitorCommands.RISKY_COLOR_MODES
    readonly property var hdrColorModes: HyprMonitorCommands.HDR_COLOR_MODES
    readonly property var colorModeOptions: [
        { value: "default", label: "Default" },
        { value: "srgb", label: "sRGB" },
        { value: "dcip3", label: "DCI P3" },
        { value: "dp3", label: "Apple P3" },
        { value: "adobe", label: "Adobe RGB" },
        { value: "wide", label: "Wide Color" },
        { value: "edid", label: "EDID" },
        { value: "hdr", label: "HDR" },
        { value: "hdrp3", label: "HDR + P3 (Test)" },
        { value: "hdrapple", label: "HDR + Apple P3 (Test)" },
        { value: "hdradobe", label: "HDR + Adobe RGB (Test)" },
        { value: "hdredid", label: "HDR (EDID)" }
    ]
    readonly property var colorModeLabels: ({
        "default": "Default",
        "srgb": "sRGB",
        "dcip3": "DCI P3",
        "dp3": "Apple P3",
        "adobe": "Adobe RGB",
        "wide": "Wide Color (BT2020)",
        "edid": "EDID (Inaccurate)",
        "hdr": "HDR",
        "hdrp3": "HDR + P3 (Test)",
        "hdrapple": "HDR + Apple P3 (Test)",
        "hdradobe": "HDR + Adobe RGB (Test)",
        "hdredid": "HDR (EDID)"
    })

    signal refreshRequested()

    function sedEscape(text) {
        return String(text).replace(/[[\]\\.*^${}()|/]/g, '\\$&');
    }

    function parseResParts(res) {
        var parts = String(res || "").split("x");
        return {
            width: parts.length > 0 ? parseInt(parts[0]) || 0 : 0,
            height: parts.length > 1 ? parseInt(parts[1]) || 0 : 0
        };
    }

    function isOutputValid(outObj) {
        if (!outObj) return false;
        var dims = parseResParts(outObj.res);
        return dims.width > 0 && dims.height > 0 && parseFloat(outObj.hz || "0") > 0;
    }

    function logicalWidth(outObj) {
        var dims = parseResParts(outObj.res);
        var scale = parseFloat(outObj.scale || "1");
        if (!isFinite(scale) || scale <= 0) scale = 1;
        return Math.round(dims.width / scale);
    }

    function logicalHeight(outObj) {
        var dims = parseResParts(outObj.res);
        var scale = parseFloat(outObj.scale || "1");
        if (!isFinite(scale) || scale <= 0) scale = 1;
        return Math.round(dims.height / scale);
    }

    function getSavedPosition(outObj) {
        var saved = backend.savedConfig[outObj.name];
        if (saved && saved.posX !== undefined && saved.posY !== undefined) {
            return {
                x: parseInt(saved.posX) || 0,
                y: parseInt(saved.posY) || 0
            };
        }
        return {
            x: Math.round(outObj.posX || 0),
            y: Math.round(outObj.posY || 0)
        };
    }

    function horizontalOverlapAmount(first, second) {
        var firstLeft = Math.round(first.posX || 0);
        var firstRight = firstLeft + logicalWidth(first);
        var secondLeft = Math.round(second.posX || 0);
        var secondRight = secondLeft + logicalWidth(second);
        return Math.max(0, Math.min(firstRight, secondRight) - Math.max(firstLeft, secondLeft));
    }

    function verticalOverlapAmount(first, second) {
        var firstTop = Math.round(first.posY || 0);
        var firstBottom = firstTop + logicalHeight(first);
        var secondTop = Math.round(second.posY || 0);
        var secondBottom = secondTop + logicalHeight(second);
        return Math.max(0, Math.min(firstBottom, secondBottom) - Math.max(firstTop, secondTop));
    }

    function outputsOverlap(first, second) {
        return horizontalOverlapAmount(first, second) > 0 && verticalOverlapAmount(first, second) > 0;
    }

    function centerYForPlacement(reference, candidate) {
        return Math.round((Math.round(reference.posY || 0) + (logicalHeight(reference) / 2)) - (logicalHeight(candidate) / 2));
    }

    function centerXForPlacement(reference, candidate) {
        return Math.round((Math.round(reference.posX || 0) + (logicalWidth(reference) / 2)) - (logicalWidth(candidate) / 2));
    }

    function candidatePlacement(reference, candidate, side) {
        if (side === "left") {
            return {
                x: Math.round(reference.posX || 0) - logicalWidth(candidate),
                y: centerYForPlacement(reference, candidate)
            };
        }
        if (side === "right") {
            return {
                x: Math.round(reference.posX || 0) + logicalWidth(reference),
                y: centerYForPlacement(reference, candidate)
            };
        }
        if (side === "top") {
            return {
                x: centerXForPlacement(reference, candidate),
                y: Math.round(reference.posY || 0) - logicalHeight(candidate)
            };
        }
        return {
            x: centerXForPlacement(reference, candidate),
            y: Math.round(reference.posY || 0) + logicalHeight(reference)
        };
    }

    function placementScore(reference, candidate, placement, preferredPosition) {
        var prefX = preferredPosition.x;
        var prefY = preferredPosition.y;
        var distance = Math.abs(placement.x - prefX) + Math.abs(placement.y - prefY);
        var centerDistance = Math.abs((placement.x + logicalWidth(candidate) / 2) - (prefX + logicalWidth(candidate) / 2))
            + Math.abs((placement.y + logicalHeight(candidate) / 2) - (prefY + logicalHeight(candidate) / 2));
        var attachPenalty = 0;
        var refCenterX = Math.round(reference.posX || 0) + logicalWidth(reference) / 2;
        var refCenterY = Math.round(reference.posY || 0) + logicalHeight(reference) / 2;
        var prefCenterX = prefX + logicalWidth(candidate) / 2;
        var prefCenterY = prefY + logicalHeight(candidate) / 2;
        var dx = prefCenterX - refCenterX;
        var dy = prefCenterY - refCenterY;
        if ((placement.x < Math.round(reference.posX || 0) && dx > 0)
            || (placement.x >= Math.round(reference.posX || 0) + logicalWidth(reference) && dx < 0)
            || (placement.y < Math.round(reference.posY || 0) && dy > 0)
            || (placement.y >= Math.round(reference.posY || 0) + logicalHeight(reference) && dy < 0)) {
            attachPenalty += 250;
        }
        return distance + centerDistance + attachPenalty;
    }

    function guessPreferredSide(reference, candidate, preferredPosition) {
        var refCenterX = Math.round(reference.posX || 0) + logicalWidth(reference) / 2;
        var refCenterY = Math.round(reference.posY || 0) + logicalHeight(reference) / 2;
        var candCenterX = preferredPosition.x + logicalWidth(candidate) / 2;
        var candCenterY = preferredPosition.y + logicalHeight(candidate) / 2;
        var dx = candCenterX - refCenterX;
        var dy = candCenterY - refCenterY;
        if (Math.abs(dx) >= Math.abs(dy)) return dx < 0 ? "left" : "right";
        return dy < 0 ? "top" : "bottom";
    }

    function findPlacementForOutput(placed, candidate, preferredPosition) {
        if (placed.length === 0) {
            return { x: preferredPosition.x, y: preferredPosition.y };
        }

        var best = null;
        for (var i = 0; i < placed.length; i++) {
            var reference = placed[i];
            var preferredSide = guessPreferredSide(reference, candidate, preferredPosition);
            var sides = [preferredSide, "right", "left", "bottom", "top"];
            var seen = {};
            for (var s = 0; s < sides.length; s++) {
                var side = sides[s];
                if (seen[side]) continue;
                seen[side] = true;
                var placement = candidatePlacement(reference, candidate, side);
                var ghost = {
                    posX: placement.x,
                    posY: placement.y,
                    res: candidate.res,
                    scale: candidate.scale
                };
                var collides = false;
                for (var j = 0; j < placed.length; j++) {
                    if (outputsOverlap(ghost, placed[j])) {
                        collides = true;
                        break;
                    }
                }
                if (collides) continue;
                var score = placementScore(reference, candidate, placement, preferredPosition);
                if (!best || score < best.score) {
                    best = { x: placement.x, y: placement.y, score: score };
                }
            }
        }

        if (best) return { x: best.x, y: best.y };

        var fallbackX = 0;
        for (var k = 0; k < placed.length; k++) {
            fallbackX = Math.max(fallbackX, Math.round(placed[k].posX || 0) + logicalWidth(placed[k]));
        }
        return { x: fallbackX, y: 0 };
    }

    function getDefaultOutputName(outs) {
        for (var i = 0; i < outs.length; i++) {
            if (outs[i].isDefault) return outs[i].name;
        }
        var savedKeys = Object.keys(backend.savedConfig || {});
        for (var j = 0; j < savedKeys.length; j++) {
            var saved = backend.savedConfig[savedKeys[j]];
            if (saved && saved.default) return savedKeys[j];
        }
        return outs.length > 0 ? outs[0].name : "";
    }

    function autoArrangeOutputs(outs) {
        if (!outs || outs.length <= 1) return outs;

        var arranged = [];
        for (var i = 0; i < outs.length; i++) arranged.push(outs[i]);

        var defaultName = getDefaultOutputName(arranged);
        var anchorIndex = 0;
        for (var a = 0; a < arranged.length; a++) {
            if (arranged[a].name === defaultName) {
                anchorIndex = a;
                break;
            }
        }

        var anchor = arranged[anchorIndex];
        if (!isOutputValid(anchor)) return arranged;

        arranged.splice(anchorIndex, 1);
        arranged.sort(function(left, right) {
            var leftPos = getSavedPosition(left);
            var rightPos = getSavedPosition(right);
            if (leftPos.x !== rightPos.x) return leftPos.x - rightPos.x;
            if (leftPos.y !== rightPos.y) return leftPos.y - rightPos.y;
            return String(left.name).localeCompare(String(right.name));
        });

        anchor.posX = 0;
        anchor.posY = 0;
        var result = [anchor];

        for (var j = 0; j < arranged.length; j++) {
            if (!isOutputValid(arranged[j])) continue;
            var preferred = getSavedPosition(arranged[j]);
            var placement = findPlacementForOutput(result, arranged[j], preferred);
            arranged[j].posX = placement.x;
            arranged[j].posY = placement.y;
            result.push(arranged[j]);
        }

        return result;
    }

    function needsAutoLayout(outs) {
        if (!outs || outs.length <= 1) return false;
        var seen = {};
        for (var i = 0; i < outs.length; i++) {
            var outObj = outs[i];
            if (!isOutputValid(outObj)) return true;
            var key = Math.round(outObj.posX || 0) + ":" + Math.round(outObj.posY || 0);
            if (seen[key]) return true;
            seen[key] = true;
            for (var j = i + 1; j < outs.length; j++) {
                if (outputsOverlap(outObj, outs[j])) return true;
            }
        }
        return false;
    }

    function syncCurrentOutputsToConfig(outs) {
        if (!outs || outs.length === 0) return;

        var nextConfig = JSON.parse(JSON.stringify(backend.savedConfig || {}));
        var changed = false;
        var defaultName = getDefaultOutputName(outs);

        for (var i = 0; i < outs.length; i++) {
            var outObj = outs[i];
            if (!isOutputValid(outObj)) continue;

            var existing = nextConfig[outObj.name] || {};
            var nextEntry = {
                res: outObj.res,
                hz: parseFloat(outObj.hz || "60").toFixed(2),
                scale: String(parseFloat(outObj.scale || "1")),
                posX: String(Math.round(outObj.posX || 0)),
                posY: String(Math.round(outObj.posY || 0)),
                default: outObj.name === defaultName,
                hdr: outObj.hdr || false,
                bitdepth: outObj.bitdepth || 8,
                vrr: (outObj.vrr !== undefined) ? outObj.vrr : 0,
                sdrLuminance: (outObj.sdrLuminance !== undefined) ? outObj.sdrLuminance : 450,
                sdrBrightness: outObj.sdrBrightness || 1.0,
                sdrSaturation: outObj.sdrSaturation || 1.0,
                colorManagement: outObj.colorManagement || "srgb",
                sdrEotf: (outObj.sdrEotf !== undefined) ? outObj.sdrEotf : 1
            };

            if (JSON.stringify(existing) !== JSON.stringify(nextEntry)) {
                nextConfig[outObj.name] = nextEntry;
                changed = true;
            }
        }

        if (!changed) return;
        backend.savedConfig = nextConfig;
        configStore.save(nextConfig);
    }

    function isHdrColorMode(mode)   { return HyprMonitorCommands.isHdrColorMode(mode); }
    function isRiskyColorMode(mode) { return HyprMonitorCommands.isRiskyColorMode(mode); }

    function parseOutputs(text) {
        var outs;
        try {
            if (CompositorService.isHyprland) outs = MonitorParsers.parseHyprlandOutputs(text);
            else if (CompositorService.isMango) outs = MonitorParsers.parseMangoOutputs(text);
            else outs = MonitorParsers.parseNiriOutputs(text);
        } catch (e) {
            Log.warn("MonitorsBackend", "Output parse error: " + e);
            return;
        }
        for (var i = 0; i < outs.length; i++) applySavedOverlay(outs[i]);
        finalizeOutputs(outs);
    }

    function applySavedOverlay(outObj) {
        var saved = backend.savedConfig[outObj.name];
        if (!saved) return;
        if (saved.default !== undefined) outObj.isDefault = !!saved.default;
        if (saved.vrr !== undefined) outObj.vrr = saved.vrr;
        if (saved.hdr !== undefined) outObj.hdr = saved.hdr;
        if (saved.bitdepth !== undefined) outObj.bitdepth = saved.bitdepth;
        if (saved.colorManagement !== undefined) outObj.colorManagement = saved.colorManagement;
        if (saved.sdrLuminance !== undefined) outObj.sdrLuminance = saved.sdrLuminance;
        if (saved.sdrBrightness !== undefined) outObj.sdrBrightness = saved.sdrBrightness;
        if (saved.sdrSaturation !== undefined) outObj.sdrSaturation = saved.sdrSaturation;
        if (saved.sdrEotf !== undefined) outObj.sdrEotf = saved.sdrEotf;
    }

    function finalizeOutputs(outs) {
        var finalOuts = outs;
        if (needsAutoLayout(finalOuts)) finalOuts = autoArrangeOutputs(finalOuts);
        syncCurrentOutputsToConfig(finalOuts);
        backend.outputs = finalOuts;
        if (backend.selectedIdx >= finalOuts.length) backend.selectedIdx = 0;
    }

    function getUniqueRes(selectedOutput) {
        if (!selectedOutput) return [];
        var seen = {};
        var result = [];
        for (var i = 0; i < selectedOutput.modes.length; i++) {
            var res = selectedOutput.modes[i].res;
            if (!seen[res]) {
                seen[res] = true;
                result.push(res);
            }
        }
        return result;
    }

    function getRefreshRates(selectedOutput, selRes) {
        if (!selectedOutput) return [];
        var rates = [];
        for (var i = 0; i < selectedOutput.modes.length; i++) {
            if (selectedOutput.modes[i].res === selRes) rates.push({ hz: selectedOutput.modes[i].hz, current: selectedOutput.modes[i].current });
        }
        rates.sort(function(a, b) { return parseFloat(b.hz) - parseFloat(a.hz); });
        var unique = [];
        var seen = {};
        for (var j = 0; j < rates.length; j++) {
            var key = parseFloat(rates[j].hz).toFixed(2);
            if (!seen[key]) {
                seen[key] = true;
                unique.push(rates[j]);
            }
        }
        return unique;
    }

    function recalcPositions(outputs, selectedOutputName, selRes, selHz, selScale, selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selSdrEotf, defaultMonitorName) {
        if (outputs.length === 0) return outputs;
        var updated = [];
        for (var i = 0; i < outputs.length; i++) {
            var isSel = (outputs[i].name === selectedOutputName);
            updated.push({
                name: outputs[i].name,
                desc: outputs[i].desc,
                res: isSel ? selRes : outputs[i].res,
                hz: isSel ? selHz : outputs[i].hz,
                scale: isSel ? selScale : parseFloat(outputs[i].scale),
                posX: isSel ? Math.round(selPosX) : Math.round(outputs[i].posX || 0),
                posY: isSel ? Math.round(selPosY) : Math.round(outputs[i].posY || 0),
                isDefault: outputs[i].name === defaultMonitorName,
                hdr: isSel ? selHdr : (outputs[i].hdr || false),
                bitdepth: isSel ? selBitdepth : (outputs[i].bitdepth || 8),
                vrr: isSel ? selVrr : ((outputs[i].vrr !== undefined) ? outputs[i].vrr : 0),
                sdrLuminance: isSel ? selSdrLuminance : ((outputs[i].sdrLuminance !== undefined) ? outputs[i].sdrLuminance : 450),
                sdrBrightness: isSel ? selSdrBrightness : (outputs[i].sdrBrightness || 1.0),
                sdrSaturation: isSel ? selSdrSaturation : (outputs[i].sdrSaturation || 1.0),
                colorManagement: isSel ? selColorManagement : (outputs[i].colorManagement || "srgb"),
                sdrEotf: isSel ? selSdrEotf : ((outputs[i].sdrEotf !== undefined) ? outputs[i].sdrEotf : 1),
                modes: outputs[i].modes
            });
        }
        return updated;
    }

    // Builds the save-config object for all monitors (no shell / jq needed).
    function buildSaveConfig(updatedOutputs, selectedOutputName, selRes, selHz, selScale, selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selSdrEotf, defaultOutputName) {
        var config = {};
        for (var i = 0; i < updatedOutputs.length; i++) {
            var mon = updatedOutputs[i];
            var isSelected = (mon.name === selectedOutputName);
            var saved = backend.savedConfig[mon.name] || {};

            var monRes   = isSelected ? (isSelected ? selRes : mon.res) : (saved.res   || mon.res);
            var monHz    = isSelected ? parseFloat(selHz).toFixed(2)    : (saved.hz    || parseFloat(mon.hz).toFixed(2));
            var monScale = isSelected ? String(parseFloat(selScale))    : (saved.scale || String(parseFloat(mon.scale)));
            var monPosX  = isSelected ? String(Math.round(mon.posX))   : (saved.posX !== undefined ? String(saved.posX) : String(Math.round(mon.posX)));
            var monPosY  = isSelected ? String(Math.round(mon.posY))   : (saved.posY !== undefined ? String(saved.posY) : String(Math.round(mon.posY)));

            config[mon.name] = {
                res:             monRes,
                hz:              monHz,
                scale:           monScale,
                posX:            monPosX,
                posY:            monPosY,
                "default":       (mon.name === defaultOutputName),
                hdr:             isSelected ? selHdr             : (saved.hdr      !== undefined ? saved.hdr      : (mon.hdr      || false)),
                bitdepth:        isSelected ? selBitdepth        : (saved.bitdepth !== undefined ? saved.bitdepth : (mon.bitdepth || 8)),
                vrr:             isSelected ? selVrr             : (saved.vrr      !== undefined ? saved.vrr      : (mon.vrr      || 0)),
                sdrLuminance:    isSelected ? selSdrLuminance    : (saved.sdrLuminance  !== undefined ? saved.sdrLuminance  : ((mon.sdrLuminance  !== undefined) ? mon.sdrLuminance  : 450)),
                sdrBrightness:   parseFloat(isSelected ? selSdrBrightness : (saved.sdrBrightness !== undefined ? saved.sdrBrightness : (mon.sdrBrightness || 1.0))).toFixed(1) * 1,
                sdrSaturation:   parseFloat(isSelected ? selSdrSaturation : (saved.sdrSaturation !== undefined ? saved.sdrSaturation : (mon.sdrSaturation || 1.0))).toFixed(1) * 1,
                colorManagement: isSelected ? selColorManagement : (saved.colorManagement !== undefined ? saved.colorManagement : (mon.colorManagement || "srgb")),
                sdrEotf:         isSelected ? selSdrEotf         : (saved.sdrEotf  !== undefined ? saved.sdrEotf  : ((mon.sdrEotf !== undefined) ? mon.sdrEotf : 1))
            };
        }
        return config;
    }

    // Builds an array of { argv: [...], delayAfter?: number } steps.
    // Each step is a direct argv process invocation — no sh -c.
    function buildApplySteps(updatedOutputs, selectedOutputName, selRes, selHz, selScale, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selSdrEotf, defaultOutputName) {
        if (CompositorService.isHyprland) {
            var hyprCmds = [];
            for (var h = 0; h < updatedOutputs.length; h++) {
                var hMon = updatedOutputs[h];
                var hSel = (hMon.name === selectedOutputName);
                var hyprCmd = HyprMonitorCommands.buildOutputCmd(
                    hMon,
                    hSel ? selRes : hMon.res,
                    hSel ? parseFloat(selHz).toFixed(2) : parseFloat(hMon.hz).toFixed(2),
                    String(parseFloat(hSel ? selScale : hMon.scale)),
                    Math.round(hMon.posX), Math.round(hMon.posY),
                    hSel,
                    { hdr: selHdr, bitdepth: selBitdepth, vrr: selVrr,
                      sdrLuminance: selSdrLuminance, sdrBrightness: selSdrBrightness,
                      sdrSaturation: selSdrSaturation, colorManagement: selColorManagement,
                      sdrEotf: selSdrEotf },
                    backend.savedConfig);
                if (hyprCmd) hyprCmds.push(hyprCmd);
            }
            return HyprMonitorCommands.assembleSteps(hyprCmds, defaultOutputName);
        }

        var steps = [];
        for (var i = 0; i < updatedOutputs.length; i++) {
            var mon = updatedOutputs[i];
            var isSelected = (mon.name === selectedOutputName);
            var monRes = isSelected ? selRes : mon.res;
            var monHz  = isSelected ? parseFloat(selHz).toFixed(2) : parseFloat(mon.hz).toFixed(2);
            var monScale = String(parseFloat(isSelected ? selScale : mon.scale));
            var monPosX  = Math.round(mon.posX);
            var monPosY  = Math.round(mon.posY);

            if (CompositorService.isMango) {
                var mangoSteps = MangoMonitorCommands.buildOutputSteps(
                    mon.name, monRes, monHz, monPosX, monPosY, monScale,
                    sedEscape, backend.mangoConfigPath);
                for (var m = 0; m < mangoSteps.length; m++) steps.push(mangoSteps[m]);
            } else {
                var applyHz6 = isSelected ? parseFloat(selHz).toFixed(6) : parseFloat(mon.hz).toFixed(6);
                steps.push(NiriMonitorCommands.buildOutputStep(
                    mon.name, monRes + "@" + applyHz6, monPosX, monPosY, monScale,
                    backend.niriScriptPath));
            }
        }
        return steps;
    }

    // Runs the next step in the apply queue.
    function _runNextStep() {
        if (_applyStep >= _applyQueue.length) {
            _onApplyComplete();
            return;
        }
        var step = _applyQueue[_applyStep];
        _applyStep++;
        Log.debug("MonitorsBackend", "Step " + _applyStep + "/" + _applyQueue.length + ": " + step.argv.join(" "));
        applyProc.running = false;
        applyProc.command = step.argv;
        applyProc.running = true;
    }

    function _onApplyComplete() {
        _applyQueue = [];
        _applyStep = 0;
        if (_pendingMangoReload) {
            _pendingMangoReload = false;
            mangoReloadProc.running = true;
        } else {
            refreshTimer.start();
        }
    }

    function applySettings(outputs, selectedOutputName, selRes, selHz, selScale, selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selSdrEotf, defaultMonitorName) {
        var updatedOutputs = recalcPositions(outputs, selectedOutputName, selRes, selHz, selScale, selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selSdrEotf, defaultMonitorName);
        var defaultOutputName = defaultMonitorName;
        if (!defaultOutputName && updatedOutputs.length > 0) {
            for (var d = 0; d < updatedOutputs.length; d++) {
                if (updatedOutputs[d].isDefault) { defaultOutputName = updatedOutputs[d].name; break; }
            }
            if (!defaultOutputName) defaultOutputName = updatedOutputs[0].name;
        }
        backend.outputs = updatedOutputs;

        // Save config via JsonDataStore (atomic write, no shell needed)
        configStore.save(buildSaveConfig(updatedOutputs, selectedOutputName, selRes, selHz, selScale,
            selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness,
            selSdrSaturation, selColorManagement, selSdrEotf, defaultOutputName));

        // Build and run compositor apply steps (direct argv, no sh -c)
        var steps = buildApplySteps(updatedOutputs, selectedOutputName, selRes, selHz, selScale,
            selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation,
            selColorManagement, selSdrEotf, defaultOutputName);
        backend._pendingMangoReload = CompositorService.isMango;
        backend._applyQueue = steps;
        backend._applyStep = 0;

        if (steps.length > 0) {
            _runNextStep();
        } else {
            _onApplyComplete();
        }
    }

    function refresh() {
        configStore.load();
    }

    Connections {
        target: CompositorService
        function onCompositorChanged() {
            if (CompositorService.compositor === "mango") {
                Log.debug("MonitorsBackend", "Mango detected, refreshing monitors");
                refresh();
            }
        }
    }

    Process {
        id: randrProc
        command: CompositorService.isHyprland ? ["hyprctl", "monitors", "all", "-j"] : (CompositorService.isMango ? ["wlr-randr"] : ["niri", "msg", "-j", "outputs"])
        property string buf: ""
        stdout: SplitParser { onRead: data => randrProc.buf += data + "\n" }
        onExited: {
            if (randrProc.buf.trim() !== "") parseOutputs(randrProc.buf);
            randrProc.buf = "";
            backend.refreshRequested();
        }
    }

    Process {
        id: applyProc
        command: []
        running: false
        stdout: SplitParser { onRead: data => Log.debug("MonitorsBackend", "[apply stdout] " + data) }
        stderr: SplitParser { onRead: data => Log.warn("MonitorsBackend", "[apply stderr] " + data) }
        onExited: {
            // Check if the step we just ran has a delay before the next step
            var prevStep = backend._applyQueue[backend._applyStep - 1];
            if (prevStep && prevStep.delayAfter && backend._applyStep < backend._applyQueue.length) {
                stepDelayTimer.interval = prevStep.delayAfter;
                stepDelayTimer.start();
            } else {
                backend._runNextStep();
            }
        }
    }

    Timer {
        id: stepDelayTimer
        repeat: false
        onTriggered: backend._runNextStep()
    }

    Process {
        id: mangoReloadProc
        command: ["mmsg", "-d", "reload_config"]
        running: false
        onExited: refreshTimer.start()
    }

    Timer {
        id: refreshTimer
        interval: 500
        repeat: false
        onTriggered: backend.refresh()
    }

    Component.onCompleted: configStore.load()

    Core.JsonDataStore {
        id: configStore
        path: backend.monitorConfigPath
        defaultValue: ({})
        onLoadedValue: function(value) {
            backend.savedConfig = value || {};
            randrProc.buf = "";
            randrProc.running = true;
        }
        onSavedValue: function(value) {
            backend.savedConfig = value || {};
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("MonitorsBackend", "Saved config parse error: " + details);
            backend.savedConfig = {};
            randrProc.buf = "";
            randrProc.running = true;
        }
    }
}
