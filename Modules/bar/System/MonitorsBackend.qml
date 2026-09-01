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
import "MonitorLayoutLogic.js"   as Layout

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
    readonly property string hyprMonitorApplyPath: configDir + "/scripts/hypr_monitor_apply.sh"
    readonly property string mangoMonitorApplyPath: configDir + "/scripts/mango_monitor_apply.sh"
    property bool _pendingMangoReload: false
    property var _applyQueue: []
    property int _applyStep: 0
    property string _applyOperation: ""
    property var _rollbackOutputs: []
    property var _rollbackConfig: ({})
    property string _rollbackSelectedName: ""
    property string _rollbackDefaultName: ""
    property var _pendingConfig: ({})
    property bool hasPendingPreview: false
    readonly property bool busy: applyProc.running || stepDelayTimer.running || mangoReloadProc.running
    readonly property string niriScriptPath: configDir + "/Modules/bar/System/niri_apply.py"

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
    signal applyCompleted(string operation)

    function deepClone(value) {
        return JSON.parse(JSON.stringify(value));
    }

    function monitorIdentity(output) {
        if (!output) return "";
        var make = String(output.make || "").trim().toLowerCase();
        var model = String(output.model || "").trim().toLowerCase();
        var serial = String(output.serial || "").trim().toLowerCase();
        if (make.length > 0 || model.length > 0 || serial.length > 0)
            return "edid:" + make + "|" + model + "|" + serial;
        var description = String(output.description || output.desc || "").trim().toLowerCase();
        return description.length > 0 ? "description:" + description : "";
    }

    // Geometry / overlap / auto-layout helpers live in MonitorLayoutLogic.js.
    // The wrappers below pass `savedConfig` through so the pure module never
    // needs to know about QML state.
    function getDefaultOutputName(outs) {
        return Layout.getDefaultOutputName(outs, backend.savedConfig);
    }

    function syncCurrentOutputsToConfig(outs) {
        if (!outs || outs.length === 0) return;

        var nextConfig = JSON.parse(JSON.stringify(backend.savedConfig || {}));
        var changed = false;
        var defaultName = getDefaultOutputName(outs);

        for (var i = 0; i < outs.length; i++) {
            var outObj = outs[i];
            if (!Layout.isOutputValid(outObj)) continue;

            var existing = nextConfig[outObj.name] || {};
            if (existing.res !== undefined || existing.hz !== undefined || existing.posX !== undefined || existing.posY !== undefined) {
                continue;
            }
            var nextEntry = {
                role: outObj.name === defaultName ? "primary" : (i === 1 ? "secondary" : (i === 2 ? "tertiary" : "display-" + (i + 1))),
                identity: monitorIdentity(outObj),
                res: outObj.res,
                hz: parseFloat(outObj.hz || "60").toFixed(2),
                scale: String(parseFloat(outObj.scale || "1")),
                autoScale: true,
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
                iccProfile: outObj.iccProfile || "",
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
        // Mango IPC exposes the current VRR/HDR state. Keep those live values
        // instead of showing a stale saved preference.
        if (!CompositorService.isMango && saved.vrr !== undefined) outObj.vrr = saved.vrr;
        if (!CompositorService.isMango && saved.hdr !== undefined) outObj.hdr = saved.hdr;
        if (saved.bitdepth !== undefined) outObj.bitdepth = saved.bitdepth;
        if (saved.colorManagement !== undefined) outObj.colorManagement = saved.colorManagement;
        if (saved.sdrLuminance !== undefined) outObj.sdrLuminance = saved.sdrLuminance;
        if (saved.sdrBrightness !== undefined) outObj.sdrBrightness = saved.sdrBrightness;
        if (saved.sdrSaturation !== undefined) outObj.sdrSaturation = saved.sdrSaturation;
        if (saved.iccProfile !== undefined) outObj.iccProfile = saved.iccProfile;
        if (saved.sdrEotf !== undefined) outObj.sdrEotf = saved.sdrEotf;
        if (saved.autoScale !== undefined) outObj.autoScale = !!saved.autoScale;
        if (saved.role !== undefined) outObj.role = saved.role;

        // Mango does not currently publish refresh rate or a mode list. Reuse
        // the saved refresh only when its saved physical mode matches the live
        // mode reconstructed from Mango's logical geometry.
        if (CompositorService.isMango && saved.res === outObj.res && saved.hz !== undefined) {
            var savedHz = parseFloat(saved.hz);
            if (!isNaN(savedHz) && savedHz > 0) {
                outObj.hz = savedHz.toFixed(3);
                outObj.modes = [{ res: outObj.res, hz: outObj.hz, current: true }];
            }
        }
    }

    function finalizeOutputs(outs) {
        var finalOuts = outs;
        if (Layout.needsAutoLayout(finalOuts)) finalOuts = Layout.autoArrangeOutputs(finalOuts, backend.savedConfig);
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

    function recalcPositions(outputs, selectedOutputName, selRes, selHz, selScale, selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selIccProfile, selSdrEotf, defaultMonitorName, selAutoScale) {
        if (outputs.length === 0) return outputs;
        var updated = [];
        for (var i = 0; i < outputs.length; i++) {
            var isSel = (outputs[i].name === selectedOutputName);
            updated.push({
                name: outputs[i].name,
                desc: outputs[i].desc,
                make: outputs[i].make || "",
                model: outputs[i].model || "",
                serial: outputs[i].serial || "",
                description: outputs[i].description || "",
                physicalWidth: outputs[i].physicalWidth || 0,
                physicalHeight: outputs[i].physicalHeight || 0,
                res: isSel ? selRes : outputs[i].res,
                hz: isSel ? selHz : outputs[i].hz,
                scale: isSel ? selScale : parseFloat(outputs[i].scale),
                autoScale: isSel ? selAutoScale : (outputs[i].autoScale !== false),
                role: outputs[i].role || "",
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
                iccProfile: isSel ? selIccProfile : (outputs[i].iccProfile || ""),
                sdrEotf: isSel ? selSdrEotf : ((outputs[i].sdrEotf !== undefined) ? outputs[i].sdrEotf : 1),
                modes: outputs[i].modes
            });
        }
        updated = Layout.reflowForGeometryChange(outputs, updated, selectedOutputName);
        if (Layout.needsAutoLayout(updated)) {
            updated = Layout.autoArrangeOutputs(updated, backend.savedConfig);
        }
        // Mark outputs moved by reflow/auto-layout. HyprMonitorCommands sees
        // the recalculated object, not the old live coordinates, so it needs
        // this explicit signal to apply neighbouring monitor moves.
        for (var u = 0; u < updated.length; u++) {
            for (var o = 0; o < outputs.length; o++) {
                if (updated[u].name !== outputs[o].name) continue;
                updated[u].layoutChanged = Math.round(updated[u].posX || 0) !== Math.round(outputs[o].posX || 0)
                    || Math.round(updated[u].posY || 0) !== Math.round(outputs[o].posY || 0);
                break;
            }
        }
        return updated;
    }

    // Builds the save-config object for all monitors (no shell / jq needed).
    function buildSaveConfig(updatedOutputs, selectedOutputName, selRes, selHz, selScale, selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selIccProfile, selSdrEotf, defaultOutputName, selAutoScale) {
        var config = {};
        for (var i = 0; i < updatedOutputs.length; i++) {
            var mon = updatedOutputs[i];
            var isSelected = (mon.name === selectedOutputName);
            var saved = backend.savedConfig[mon.name] || {};

            // Mango reports live per-output geometry. Snapshot that live state
            // for untouched outputs instead of carrying an older saved scale
            // into the next apply operation.
            var preserveMangoLive = CompositorService.isMango && !isSelected;
            var monRes   = isSelected ? selRes : (preserveMangoLive ? mon.res : (saved.res || mon.res));
            var monHz    = isSelected ? parseFloat(selHz).toFixed(2) : (preserveMangoLive ? parseFloat(mon.hz).toFixed(2) : (saved.hz || parseFloat(mon.hz).toFixed(2)));
            var monScale = isSelected ? String(parseFloat(selScale)) : (preserveMangoLive ? String(parseFloat(mon.scale)) : (saved.scale || String(parseFloat(mon.scale))));
            // recalcPositions may move neighbouring outputs after a scale or
            // resolution change. Persist the resulting coordinates for every
            // output so a restart cannot restore an overlapping layout.
            var monPosX  = String(Math.round(mon.posX));
            var monPosY  = String(Math.round(mon.posY));

            config[mon.name] = {
                role:            saved.role || (mon.name === defaultOutputName ? "primary" : (i === 1 ? "secondary" : (i === 2 ? "tertiary" : "display-" + (i + 1)))),
                identity:        saved.identity || monitorIdentity(mon),
                res:             monRes,
                hz:              monHz,
                scale:           monScale,
                autoScale:       isSelected ? !!selAutoScale : (mon.autoScale !== false),
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
                iccProfile:      isSelected ? selIccProfile : (saved.iccProfile !== undefined ? saved.iccProfile : (mon.iccProfile || "")),
                sdrEotf:         isSelected ? selSdrEotf         : (saved.sdrEotf  !== undefined ? saved.sdrEotf  : ((mon.sdrEotf !== undefined) ? mon.sdrEotf : 1))
            };
        }
        return config;
    }

    // Builds an array of { argv: [...], delayAfter?: number } steps.
    // Each step is a direct argv process invocation — no sh -c.
    function buildApplySteps(updatedOutputs, selectedOutputName, selRes, selHz, selScale, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selIccProfile, selSdrEotf, defaultOutputName) {
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
                      iccProfile: selIccProfile, sdrEotf: selSdrEotf },
                    backend.savedConfig,
                    !!hMon.layoutChanged,
                    backend.hyprMonitorApplyPath);
                if (hyprCmd) hyprCmds.push(hyprCmd);
            }
            return HyprMonitorCommands.assembleSteps(hyprCmds, defaultOutputName, backend.hyprMonitorApplyPath);
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
                // Do not rewrite every monitor rule for a single-output scale
                // change. Rewriting an untouched output could reapply a stale
                // saved scale and made both monitors appear to change together.
                if (!MangoMonitorCommands.shouldApplyOutput(isSelected, !!mon.layoutChanged)) continue;
                var mangoHdr = isSelected ? selHdr : (mon.hdr || false);
                var mangoVrr = isSelected ? selVrr : ((mon.vrr !== undefined) ? mon.vrr : 0);
                var mangoSteps = MangoMonitorCommands.buildOutputSteps(
                    mon.name, monRes, monHz, monPosX, monPosY, monScale,
                    { hdr: mangoHdr, vrr: mangoVrr }, backend.mangoMonitorApplyPath);
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
        var finishedOperation = _applyOperation;
        _applyOperation = "";
        _applyQueue = [];
        _applyStep = 0;
        if (_pendingMangoReload) {
            _pendingMangoReload = false;
            mangoReloadProc.running = true;
        } else if (finishedOperation !== "preview") {
            refreshTimer.start();
        }
        backend.applyCompleted(finishedOperation);
    }

    function applySettings(outputs, selectedOutputName, selRes, selHz, selScale, selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selIccProfile, selSdrEotf, defaultMonitorName, selAutoScale) {
        if (backend.busy || backend.hasPendingPreview) return;

        backend._rollbackOutputs = deepClone(outputs);
        backend._rollbackConfig = deepClone(backend.savedConfig || {});
        backend._rollbackSelectedName = selectedOutputName;
        backend._rollbackDefaultName = getDefaultOutputName(outputs);

        var updatedOutputs = recalcPositions(outputs, selectedOutputName, selRes, selHz, selScale, selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selIccProfile, selSdrEotf, defaultMonitorName, selAutoScale);
        var defaultOutputName = defaultMonitorName;
        if (!defaultOutputName && updatedOutputs.length > 0) {
            for (var d = 0; d < updatedOutputs.length; d++) {
                if (updatedOutputs[d].isDefault) { defaultOutputName = updatedOutputs[d].name; break; }
            }
            if (!defaultOutputName) defaultOutputName = updatedOutputs[0].name;
        }
        backend.outputs = updatedOutputs;

        // Keep the new configuration in memory during the ten-second preview.
        // It is persisted only after the user explicitly chooses Keep.
        backend._pendingConfig = buildSaveConfig(updatedOutputs, selectedOutputName, selRes, selHz, selScale,
            selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness,
            selSdrSaturation, selColorManagement, selIccProfile, selSdrEotf, defaultOutputName, selAutoScale);
        backend.hasPendingPreview = true;

        // Build and run compositor apply steps (direct argv, no sh -c)
        var steps = buildApplySteps(updatedOutputs, selectedOutputName, selRes, selHz, selScale,
            selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation,
            selColorManagement, selIccProfile, selSdrEotf, defaultOutputName);
        backend._pendingMangoReload = CompositorService.isMango;
        backend._applyQueue = steps;
        backend._applyStep = 0;
        backend._applyOperation = "preview";

        if (steps.length > 0) {
            _runNextStep();
        } else {
            _onApplyComplete();
        }
    }

    function confirmPreview() {
        if (!backend.hasPendingPreview) return false;
        configStore.save(deepClone(backend._pendingConfig));
        backend.hasPendingPreview = false;
        backend._pendingConfig = ({});
        backend._rollbackOutputs = [];
        backend._rollbackConfig = ({});
        backend._rollbackSelectedName = "";
        backend._rollbackDefaultName = "";
        refreshTimer.start();
        return true;
    }

    function revertPreview() {
        if (!backend.hasPendingPreview || backend.busy || backend._rollbackOutputs.length === 0) return false;

        var restoreOutputs = deepClone(backend._rollbackOutputs);
        var restoreConfig = deepClone(backend._rollbackConfig || {});
        var selectedName = backend._rollbackSelectedName;
        var selected = null;
        for (var i = 0; i < restoreOutputs.length; i++) {
            restoreOutputs[i].layoutChanged = true;
            if (restoreOutputs[i].name === selectedName) selected = restoreOutputs[i];
        }
        if (!selected && restoreOutputs.length > 0) {
            selected = restoreOutputs[0];
            selectedName = selected.name;
        }
        if (!selected) return false;

        var saved = restoreConfig[selectedName] || {};
        var restoreDefault = backend._rollbackDefaultName || getDefaultOutputName(restoreOutputs);
        backend.savedConfig = restoreConfig;
        backend.outputs = restoreOutputs;

        var restoreRes = CompositorService.isMango ? selected.res : (saved.res || selected.res);
        var restoreHz = CompositorService.isMango ? selected.hz : (saved.hz || selected.hz);
        var restoreScale = CompositorService.isMango ? selected.scale : (saved.scale || selected.scale);
        var restoreHdr = CompositorService.isMango ? (selected.hdr || false) : (saved.hdr !== undefined ? saved.hdr : (selected.hdr || false));
        var restoreBitdepth = saved.bitdepth !== undefined ? saved.bitdepth : (selected.bitdepth || 8);
        var restoreVrr = CompositorService.isMango ? (selected.vrr || 0) : (saved.vrr !== undefined ? saved.vrr : (selected.vrr || 0));
        var restoreLuminance = saved.sdrLuminance !== undefined ? saved.sdrLuminance : (selected.sdrLuminance || 450);
        var restoreBrightness = saved.sdrBrightness !== undefined ? saved.sdrBrightness : (selected.sdrBrightness || 1.0);
        var restoreSaturation = saved.sdrSaturation !== undefined ? saved.sdrSaturation : (selected.sdrSaturation || 1.0);
        var restoreColor = saved.colorManagement !== undefined ? saved.colorManagement : (selected.colorManagement || "srgb");
        var restoreIcc = saved.iccProfile !== undefined ? saved.iccProfile : (selected.iccProfile || "");
        var restoreEotf = saved.sdrEotf !== undefined ? saved.sdrEotf : (selected.sdrEotf !== undefined ? selected.sdrEotf : 1);

        var steps = buildApplySteps(restoreOutputs, selectedName, restoreRes, restoreHz, restoreScale,
            restoreHdr, restoreBitdepth, restoreVrr, restoreLuminance, restoreBrightness,
            restoreSaturation, restoreColor, restoreIcc, restoreEotf, restoreDefault);

        backend.hasPendingPreview = false;
        backend._pendingConfig = ({});
        backend._rollbackOutputs = [];
        backend._rollbackConfig = ({});
        backend._rollbackSelectedName = "";
        backend._rollbackDefaultName = "";
        backend._pendingMangoReload = CompositorService.isMango;
        backend._applyQueue = steps;
        backend._applyStep = 0;
        backend._applyOperation = "revert";

        if (steps.length > 0) backend._runNextStep();
        else backend._onApplyComplete();
        return true;
    }

    function refresh() {
        if (backend.hasPendingPreview) return;
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
        command: CompositorService.isHyprland ? ["hyprctl", "monitors", "all", "-j"] : (CompositorService.isMango ? ["mmsg", "get", "all-monitors"] : ["niri", "msg", "-j", "outputs"])
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
        command: ["mmsg", "dispatch", "reload_config"]
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
