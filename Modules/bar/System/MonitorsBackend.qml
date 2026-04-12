import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Services"
import "../../../Services/core" as Core
import "../../../Services/core/Log.js" as Log

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
    readonly property string monitorConfigTmpPath: monitorConfigPath + ".tmp"

    readonly property var riskyColorModes: ["dcip3", "dp3", "adobe"]
    readonly property var hdrColorModes: ["hdr", "hdredid", "hdrp3", "hdrapple", "hdradobe"]
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

    function shellQuote(text) {
        return "'" + String(text).replace(/'/g, "'\\''") + "'";
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

    function isHdrColorMode(mode) {
        return backend.hdrColorModes.indexOf(mode) >= 0;
    }

    function isRiskyColorMode(mode) {
        return backend.riskyColorModes.indexOf(mode) >= 0;
    }

    function parseOutputs(text) {
        if (CompositorService.isHyprland) parseHyprland(text);
        else if (CompositorService.isMango) parseMango(text);
        else parseAll(text);
    }

    function applySavedOverlay(outObj, includeColorState, includeSdrTuningState) {
        var saved = backend.savedConfig[outObj.name];
        if (!saved) return;
        if (saved.default !== undefined) outObj.isDefault = !!saved.default;
        if (includeColorState) {
            if (saved.vrr !== undefined) outObj.vrr = saved.vrr;
            if (saved.hdr !== undefined) outObj.hdr = saved.hdr;
            if (saved.bitdepth !== undefined) outObj.bitdepth = saved.bitdepth;
            if (saved.colorManagement !== undefined) outObj.colorManagement = saved.colorManagement;
        }
        if (includeSdrTuningState) {
            if (saved.sdrLuminance !== undefined) outObj.sdrLuminance = saved.sdrLuminance;
            if (saved.sdrBrightness !== undefined) outObj.sdrBrightness = saved.sdrBrightness;
            if (saved.sdrSaturation !== undefined) outObj.sdrSaturation = saved.sdrSaturation;
            if (saved.sdrEotf !== undefined) outObj.sdrEotf = saved.sdrEotf;
        }
    }

    function finalizeOutputs(outs) {
        var finalOuts = outs;
        if (needsAutoLayout(finalOuts)) finalOuts = autoArrangeOutputs(finalOuts);
        syncCurrentOutputsToConfig(finalOuts);
        backend.outputs = finalOuts;
        if (backend.selectedIdx >= finalOuts.length) backend.selectedIdx = 0;
    }

    function parseHyprland(text) {
        try {
            var data = JSON.parse(text);
            var outs = [];
            for (var i = 0; i < data.length; i++) {
                var info = data[i];
                var outObj = {
                    name: info.name,
                    desc: (info.make || "") + " " + (info.model || ""),
                    res: info.width + "x" + info.height,
                    hz: info.refreshRate ? info.refreshRate.toFixed(3) : "60.000",
                    scale: info.scale ? info.scale.toFixed(2) : "1.00",
                    posX: info.x || 0,
                    posY: info.y || 0,
                    isDefault: false,
                    hdr: (info.colorManagementPreset === "hdr" || info.colorManagement === "hdr" || info.cm === "hdr") ? true : false,
                    bitdepth: (info.currentFormat && info.currentFormat.indexOf("2101010") >= 0) ? 10 : (info.bitdepth || 8),
                    vrr: (info.vrr === true) ? 1 : ((info.vrr === false) ? 0 : (info.vrr || 0)),
                    sdrLuminance: (info.sdrMaxLuminance !== undefined) ? info.sdrMaxLuminance : ((info.sdr_max_luminance !== undefined) ? info.sdr_max_luminance : 450),
                    sdrBrightness: (info.sdrBrightness !== undefined) ? info.sdrBrightness : ((info.sdrbrightness !== undefined) ? info.sdrbrightness : 1.0),
                    sdrSaturation: (info.sdrSaturation !== undefined) ? info.sdrSaturation : ((info.sdrsaturation !== undefined) ? info.sdrsaturation : 1.0),
                    colorManagement: info.colorManagementPreset || info.cm || info.colorManagement || "srgb",
                    sdrEotf: info.sdr_eotf || info.sdreotf || 1,
                    modes: []
                };

                if (info.availableModes) {
                    for (var m = 0; m < info.availableModes.length; m++) {
                        var modeStr = info.availableModes[m];
                        var parts = modeStr.split("@");
                        if (parts.length !== 2) continue;
                        var res = parts[0];
                        var hz = parts[1].replace("Hz", "");
                        var formattedHz = parseFloat(hz).toFixed(3);
                        var isCur = (res === outObj.res && Math.abs(parseFloat(hz) - parseFloat(outObj.hz)) < 1.0);
                        outObj.modes.push({ res: res, hz: formattedHz, current: isCur });
                        if (isCur) outObj.hz = formattedHz;
                    }
                }

                applySavedOverlay(outObj, true, true);
                outs.push(outObj);
            }
            finalizeOutputs(outs);
        } catch (e) {
            Log.warn("MonitorsBackend", "Hyprland outputs parse error: " + e);
        }
    }

    function parseAll(text) {
        try {
            var data = JSON.parse(text);
            var outs = [];
            var keys = Object.keys(data);
            for (var i = 0; i < keys.length; i++) {
                var name = keys[i];
                var info = data[name];
                var outObj = {
                    name: name,
                    desc: (info.make || "") + " " + (info.model || ""),
                    res: "",
                    hz: "",
                    scale: "1.0",
                    posX: 0,
                    posY: 0,
                    isDefault: false,
                    modes: []
                };

                if (info.logical) {
                    outObj.posX = info.logical.x;
                    outObj.posY = info.logical.y;
                    outObj.scale = info.logical.scale.toFixed(2);
                }

                if (info.modes) {
                    for (var m = 0; m < info.modes.length; m++) {
                        var mode = info.modes[m];
                        var res = mode.width + "x" + mode.height;
                        var hz = (mode.refresh_rate / 1000.0).toFixed(3);
                        var isCur = (m === info.current_mode);
                        outObj.modes.push({ res: res, hz: hz, current: isCur });
                        if (isCur) {
                            outObj.res = res;
                            outObj.hz = hz;
                        }
                    }
                }
                applySavedOverlay(outObj, true, true);
                outs.push(outObj);
            }
            finalizeOutputs(outs);
        } catch (e) {
            Log.warn("MonitorsBackend", "Niri outputs parse error: " + e);
        }
    }

    function parseMango(text) {
        try {
            var outs = [];
            var lines = text.split("\n");
            var current = null;
            var inModes = false;

            for (var i = 0; i < lines.length; i++) {
                var line = lines[i];
                var trimmed = line.trim();
                if (trimmed === "") continue;

                if (line.length > 0 && line[0] !== " " && line[0] !== "\t") {
                    if (current) outs.push(current);
                    var nameEnd = trimmed.indexOf(" ");
                    var outName = nameEnd > 0 ? trimmed.substring(0, nameEnd) : trimmed;
                    var descPart = nameEnd > 0 ? trimmed.substring(nameEnd + 1) : "";
                    descPart = descPart.replace(/^"|"$/g, "").trim();
                    descPart = descPart.replace(/\s*\([^)]*\)\s*$/, "").trim();
                    current = {
                        name: outName,
                        desc: descPart || outName,
                        res: "",
                        hz: "",
                        scale: "1.00",
                        posX: 0,
                        posY: 0,
                        isDefault: false,
                        modes: []
                    };
                    inModes = false;
                    continue;
                }

                if (!current) continue;
                if (trimmed === "Modes:") {
                    inModes = true;
                    continue;
                }
                if (inModes && trimmed.indexOf("px,") > 0) {
                    var modeMatch = trimmed.match(/(\d+)x(\d+)\s+px,\s+([\d.]+)\s+Hz(.*)/);
                    if (modeMatch) {
                        var res = modeMatch[1] + "x" + modeMatch[2];
                        var hz = parseFloat(modeMatch[3]).toFixed(3);
                        var isCurrent = (modeMatch[4] || "").indexOf("current") >= 0;
                        current.modes.push({ res: res, hz: hz, current: isCurrent });
                        if (isCurrent) {
                            current.res = res;
                            current.hz = hz;
                        }
                    }
                    continue;
                }
                if (trimmed.startsWith("Position:")) {
                    inModes = false;
                    var posParts = trimmed.substring("Position:".length).trim().split(",");
                    if (posParts.length >= 2) {
                        current.posX = parseInt(posParts[0]) || 0;
                        current.posY = parseInt(posParts[1]) || 0;
                    }
                    continue;
                }
                if (trimmed.startsWith("Scale:")) {
                    inModes = false;
                    var scaleVal = parseFloat(trimmed.substring("Scale:".length).trim());
                    if (!isNaN(scaleVal)) current.scale = scaleVal.toFixed(2);
                    continue;
                }
                if (trimmed.startsWith("Enabled:") || trimmed.startsWith("Transform:") || trimmed.startsWith("Physical size:")) {
                    inModes = false;
                }
            }
            if (current) {
                applySavedOverlay(current, true, true);
                outs.push(current);
            }
            finalizeOutputs(outs);
        } catch (e) {
            Log.warn("MonitorsBackend", "Mango wlr-randr parse error: " + e);
        }
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

    function monitorSettingChanged(mon, monRes, monHz, monScale, monPosX, monPosY, monHdr, monBitdepth, monVrr, monSdrLum, monSdrBri, monSdrSat, monCm, monEotf) {
        var currentHdr = mon.hdr || false;
        var currentBitdepth = mon.bitdepth || 8;
        var currentVrr = (mon.vrr !== undefined) ? mon.vrr : 0;
        var currentLum = (mon.sdrLuminance !== undefined) ? mon.sdrLuminance : 450;
        var currentBri = mon.sdrBrightness || 1.0;
        var currentSat = mon.sdrSaturation || 1.0;
        var currentCm = mon.colorManagement || "srgb";
        var currentEotf = (mon.sdrEotf !== undefined) ? mon.sdrEotf : 1;

        if (monRes !== mon.res) return true;
        if (Math.abs(parseFloat(monHz) - parseFloat(mon.hz)) >= 0.01) return true;
        if (Math.abs(parseFloat(monScale) - parseFloat(mon.scale)) >= 0.01) return true;
        if (monPosX !== Math.round(mon.posX)) return true;
        if (monPosY !== Math.round(mon.posY)) return true;
        if (monHdr !== currentHdr) return true;
        if (monBitdepth !== currentBitdepth) return true;
        if (monVrr !== currentVrr) return true;
        if (Math.abs(monSdrLum - currentLum) >= 1) return true;
        if (Math.abs(monSdrBri - currentBri) >= 0.01) return true;
        if (Math.abs(monSdrSat - currentSat) >= 0.01) return true;
        if (monCm !== currentCm) return true;
        if (monEotf !== currentEotf) return true;
        return false;
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

    function buildApplyCommand(outputs, selectedOutputName, selRes, selHz, selScale, selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selSdrEotf, defaultMonitorName) {
        var updatedOutputs = recalcPositions(outputs, selectedOutputName, selRes, selHz, selScale, selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selSdrEotf, defaultMonitorName);
        var cmds = [];
        var saveCmds = [];
        var defaultOutputName = defaultMonitorName;

        if (!defaultOutputName && updatedOutputs.length > 0) {
            for (var d = 0; d < updatedOutputs.length; d++) {
                if (updatedOutputs[d].isDefault) {
                    defaultOutputName = updatedOutputs[d].name;
                    break;
                }
            }
            if (!defaultOutputName) defaultOutputName = updatedOutputs[0].name;
        }

        saveCmds.push("mkdir -p " + backend.shellQuote(backend.configDir) + " && ([ -s " + backend.shellQuote(backend.monitorConfigPath) + " ] || echo '{}' > " + backend.shellQuote(backend.monitorConfigPath) + ")");

        for (var i = 0; i < updatedOutputs.length; i++) {
            var mon = updatedOutputs[i];
            var isSelected = (mon.name === selectedOutputName);
            var monRes = isSelected ? selRes : mon.res;
            var monHz = isSelected ? parseFloat(selHz).toFixed(2) : parseFloat(mon.hz).toFixed(2);
            var monScale = String(parseFloat(isSelected ? selScale : mon.scale));
            var monPosX = Math.round(mon.posX);
            var monPosY = Math.round(mon.posY);

            if (CompositorService.isHyprland) {
                var savedMon = backend.savedConfig[mon.name] || {};
                var monHdr = isSelected ? selHdr : (savedMon.hdr !== undefined ? savedMon.hdr : (mon.hdr || false));
                var monBitdepth = isSelected ? selBitdepth : (savedMon.bitdepth !== undefined ? savedMon.bitdepth : (mon.bitdepth || 8));
                var monVrr = isSelected ? selVrr : (savedMon.vrr !== undefined ? savedMon.vrr : (mon.vrr || 0));
                var monSdrLum = isSelected ? selSdrLuminance : (savedMon.sdrLuminance !== undefined ? savedMon.sdrLuminance : ((mon.sdrLuminance !== undefined) ? mon.sdrLuminance : 450));
                var monSdrBri = isSelected ? selSdrBrightness : (savedMon.sdrBrightness !== undefined ? savedMon.sdrBrightness : (mon.sdrBrightness || 1.0));
                var monSdrSat = isSelected ? selSdrSaturation : (savedMon.sdrSaturation !== undefined ? savedMon.sdrSaturation : (mon.sdrSaturation || 1.0));
                var monCm = isSelected ? selColorManagement : (savedMon.colorManagement !== undefined ? savedMon.colorManagement : (mon.colorManagement || "srgb"));
                var monEotf = isSelected ? selSdrEotf : (savedMon.sdrEotf !== undefined ? savedMon.sdrEotf : ((mon.sdrEotf !== undefined) ? mon.sdrEotf : 1));
                var monCmd = "hyprctl keyword monitor " + mon.name + "," + monRes + "@" + monHz + "," + monPosX + "x" + monPosY + "," + monScale;

                if (isRiskyColorMode(monCm)) monVrr = 0;

                if (monHdr || isHdrColorMode(monCm)) {
                    var appliedCm = (monCm === "hdredid") ? "hdredid" : "hdr";
                    monCmd += ",bitdepth," + monBitdepth + ",vrr," + monVrr + ",cm," + appliedCm + ",sdrbrightness," + monSdrBri.toFixed(1) + ",sdrsaturation," + monSdrSat.toFixed(1);
                } else if (monCm === "default") {
                    monCmd += ",bitdepth," + monBitdepth + ",vrr," + monVrr;
                } else {
                    monCmd += ",bitdepth," + monBitdepth + ",vrr," + monVrr + ",cm," + monCm;
                }

                var changed = monitorSettingChanged(mon, monRes, monHz, monScale, monPosX, monPosY, monHdr, monBitdepth, monVrr, monSdrLum, monSdrBri, monSdrSat, monCm, monEotf);
                var needsCmReset = isSelected && monCm !== (mon.colorManagement || "srgb");
                if (needsCmReset) {
                    var resetCmd = "hyprctl keyword monitor " + mon.name + "," + monRes + "@" + monHz + "," + monPosX + "x" + monPosY + "," + monScale + ",bitdepth,10,vrr,0,cm,srgb";
                    monCmd = resetCmd + " && sleep 0.2 && " + monCmd;
                }
                if (isSelected || changed) cmds.push({ cmd: monCmd, batchable: !needsCmReset });
            } else if (CompositorService.isMango) {
                var resParts = monRes.split("x");
                var monRefresh = Math.round(parseFloat(monHz));
                var ruleStr = "monitorrule=name:" + mon.name + ",width:" + resParts[0] + ",height:" + resParts[1] + ",refresh:" + monRefresh + ",x:" + monPosX + ",y:" + monPosY + ",scale:" + monScale;
                cmds.push("sed -i '/^monitorrule=name:" + mon.name + "/d' ~/.config/mango/config.conf && sed -i '/^# Monitor Rules$/a " + ruleStr + "' ~/.config/mango/config.conf");
            } else {
                var applyHz6 = isSelected ? parseFloat(selHz).toFixed(6) : parseFloat(mon.hz).toFixed(6);
                var niriConf = "$HOME/.config/niri/config.kdl";
                var newMode = monRes + "@" + applyHz6;
                cmds.push("python3 -c \"\n"
                    + "import re, os\n"
                    + "conf = os.path.expanduser('" + niriConf + "')\n"
                    + "with open(conf) as f: text = f.read()\n"
                    + "pattern = r'(output\\\\s+\\\"" + mon.name + "\\\"\\\\s*\\\\{)[^}]*(\\\\})'\n"
                    + "replacement = r'\\\\1\\n    mode \\\"" + newMode + "\\\"\\n    position x=" + monPosX + " y=" + monPosY + "\\n    scale " + monScale + "\\n\\\\2'\n"
                    + "if re.search(pattern, text):\n"
                    + "    new_text = re.sub(pattern, replacement, text, flags=re.DOTALL)\n"
                    + "else:\n"
                    + "    new_text = text.rstrip() + '\\n\\noutput \\\"" + mon.name + "\\\" {\\n    mode \\\"" + newMode + "\\\"\\n    position x=" + monPosX + " y=" + monPosY + "\\n    scale " + monScale + "\\n}\\n'\n"
                    + "with open(conf, 'w') as f: f.write(new_text)\n"
                    + "print('Updated ' + conf)\n"
                    + "\"");
            }

            var monDefaultSave = (mon.name === defaultOutputName);
            var saved = backend.savedConfig[mon.name] || {};
            var monHdrSave = isSelected ? selHdr : (saved.hdr !== undefined ? saved.hdr : (mon.hdr || false));
            var monBdSave = isSelected ? selBitdepth : (saved.bitdepth !== undefined ? saved.bitdepth : (mon.bitdepth || 8));
            var monVrrSave = isSelected ? selVrr : (saved.vrr !== undefined ? saved.vrr : (mon.vrr || 0));
            var monLumSave = isSelected ? selSdrLuminance : (saved.sdrLuminance !== undefined ? saved.sdrLuminance : ((mon.sdrLuminance !== undefined) ? mon.sdrLuminance : 450));
            var monBriSave = isSelected ? selSdrBrightness : (saved.sdrBrightness !== undefined ? saved.sdrBrightness : (mon.sdrBrightness || 1.0));
            var monSatSave = isSelected ? selSdrSaturation : (saved.sdrSaturation !== undefined ? saved.sdrSaturation : (mon.sdrSaturation || 1.0));
            var monCmSave = isSelected ? selColorManagement : (saved.colorManagement !== undefined ? saved.colorManagement : (mon.colorManagement || "srgb"));
            var monEotfSave = isSelected ? selSdrEotf : (saved.sdrEotf !== undefined ? saved.sdrEotf : ((mon.sdrEotf !== undefined) ? mon.sdrEotf : 1));
            var monResSave = isSelected ? monRes : (saved.res || monRes);
            var monHzSave = isSelected ? monHz : (saved.hz || monHz);
            var monScaleSave = isSelected ? monScale : (saved.scale || monScale);
            var monPosXSave = isSelected ? String(monPosX) : (saved.posX !== undefined ? String(saved.posX) : String(monPosX));
            var monPosYSave = isSelected ? String(monPosY) : (saved.posY !== undefined ? String(saved.posY) : String(monPosY));
            var jqFilter = ".[" + JSON.stringify(mon.name) + "] = {"
                + "\"res\": " + JSON.stringify(monResSave) + ", "
                + "\"hz\": " + JSON.stringify(monHzSave) + ", "
                + "\"scale\": " + JSON.stringify(monScaleSave) + ", "
                + "\"posX\": " + JSON.stringify(monPosXSave) + ", "
                + "\"posY\": " + JSON.stringify(monPosYSave) + ", "
                + "\"default\": " + (monDefaultSave ? "true" : "false") + ", "
                + "\"hdr\": " + (monHdrSave ? "true" : "false") + ", "
                + "\"bitdepth\": " + monBdSave + ", "
                + "\"vrr\": " + monVrrSave + ", "
                + "\"sdrLuminance\": " + monLumSave + ", "
                + "\"sdrBrightness\": " + parseFloat(monBriSave).toFixed(1) + ", "
                + "\"sdrSaturation\": " + parseFloat(monSatSave).toFixed(1) + ", "
                + "\"colorManagement\": " + JSON.stringify(monCmSave) + ", "
                + "\"sdrEotf\": " + monEotfSave
                + "}";
            saveCmds.push("jq " + backend.shellQuote(jqFilter) + " " + backend.shellQuote(backend.monitorConfigPath) + " > " + backend.shellQuote(backend.monitorConfigTmpPath) + " && mv " + backend.shellQuote(backend.monitorConfigTmpPath) + " " + backend.shellQuote(backend.monitorConfigPath));
        }

        var fullCmdParts = [];
        if (CompositorService.isHyprland && cmds.length > 0) {
            var batchable = [];
            var nonBatchable = [];
            for (var ci = 0; ci < cmds.length; ci++) {
                if (cmds[ci].batchable) batchable.push(cmds[ci].cmd.replace(/^hyprctl /, ""));
                else nonBatchable.push(cmds[ci].cmd);
            }
            if (nonBatchable.length > 0) fullCmdParts.push(nonBatchable.join(" && "));
            if (batchable.length > 0) {
                if (defaultOutputName) batchable.push("dispatch focusmonitor " + defaultOutputName);
                fullCmdParts.push("hyprctl --batch " + backend.shellQuote(batchable.join(" ; ")));
            } else if (defaultOutputName) {
                fullCmdParts.push("hyprctl dispatch focusmonitor " + defaultOutputName);
            }
        } else {
            if (cmds.length > 0) {
                var plainCmds = cmds.map(function(c) { return c.cmd || c; });
                fullCmdParts.push(plainCmds.join(" && "));
            }
            if (defaultOutputName && CompositorService.isHyprland) fullCmdParts.push("hyprctl dispatch focusmonitor " + defaultOutputName);
        }
        if (saveCmds.length > 0) fullCmdParts.push(saveCmds.join(" && "));
        var fullCmd = fullCmdParts.join(" ; ");
        if (CompositorService.isMango) fullCmd += " && mmsg -d reload_config";
        return { command: fullCmd, updatedOutputs: updatedOutputs };
    }

    function applySettings(outputs, selectedOutputName, selRes, selHz, selScale, selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selSdrEotf, defaultMonitorName) {
        var applyData = buildApplyCommand(outputs, selectedOutputName, selRes, selHz, selScale, selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selSdrEotf, defaultMonitorName);
        backend.outputs = applyData.updatedOutputs;
        Log.debug("MonitorsBackend", "Running: " + applyData.command);
        applyProc.running = false;
        applyProc.command = ["sh", "-c", applyData.command];
        applyProc.running = true;
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
        stdout: SplitParser { onRead: data => Log.debug("MonitorsBackend", "[monitor apply stdout] " + data) }
        stderr: SplitParser { onRead: data => Log.warn("MonitorsBackend", "[monitor apply stderr] " + data) }
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
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("MonitorsBackend", "Saved config parse error: " + details);
            backend.savedConfig = {};
            randrProc.buf = "";
            randrProc.running = true;
        }
    }
}
