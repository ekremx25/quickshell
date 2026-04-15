.pragma library

// Color mode classification — kept here so MonitorsBackend can delegate
// isHdrColorMode / isRiskyColorMode to this library.
var RISKY_COLOR_MODES = ["dcip3", "dp3", "adobe"];
var HDR_COLOR_MODES   = ["hdr", "hdredid", "hdrp3", "hdrapple", "hdradobe"];

function isRiskyColorMode(mode) { return RISKY_COLOR_MODES.indexOf(mode) >= 0; }
function isHdrColorMode(mode)   { return HDR_COLOR_MODES.indexOf(mode) >= 0; }

// Returns true when any Hyprland-specific setting differs from the live output.
function monitorSettingChanged(mon, monRes, monHz, monScale, monPosX, monPosY,
                               monHdr, monBitdepth, monVrr, monSdrLum, monSdrBri,
                               monSdrSat, monCm, monEotf) {
    if (monRes   !== mon.res)  return true;
    if (Math.abs(parseFloat(monHz)    - parseFloat(mon.hz))    >= 0.01)  return true;
    if (Math.abs(parseFloat(monScale) - parseFloat(mon.scale)) >= 0.01)  return true;
    if (monPosX  !== Math.round(mon.posX)) return true;
    if (monPosY  !== Math.round(mon.posY)) return true;
    if (monHdr   !== (mon.hdr || false))              return true;
    if (monBitdepth !== (mon.bitdepth || 8))          return true;
    if (monVrr   !== ((mon.vrr !== undefined) ? mon.vrr : 0)) return true;
    if (Math.abs(monSdrLum - ((mon.sdrLuminance !== undefined) ? mon.sdrLuminance : 450)) >= 1) return true;
    if (Math.abs(monSdrBri - (mon.sdrBrightness || 1.0)) >= 0.01) return true;
    if (Math.abs(monSdrSat - (mon.sdrSaturation || 1.0)) >= 0.01) return true;
    if (monCm    !== (mon.colorManagement || "srgb")) return true;
    if (monEotf  !== ((mon.sdrEotf !== undefined) ? mon.sdrEotf : 1)) return true;
    return false;
}

// Builds the monitor argument string for hyprctl keyword monitor.
function buildMonitorArg(monName, monRes, monHz, monPosX, monPosY, monScale,
                         monHdr, monBd, monVrr, monSdrBri, monSdrSat, monCm) {
    var arg = monName + "," + monRes + "@" + monHz + "," + monPosX + "x" + monPosY + "," + monScale;
    if (monHdr || isHdrColorMode(monCm)) {
        var appliedCm = (monCm === "hdredid") ? "hdredid" : "hdr";
        arg += ",bitdepth," + monBd + ",vrr," + monVrr + ",cm," + appliedCm + ",sdrbrightness," + monSdrBri.toFixed(1) + ",sdrsaturation," + monSdrSat.toFixed(1);
    } else if (monCm === "default") {
        arg += ",bitdepth," + monBd + ",vrr," + monVrr;
    } else {
        arg += ",bitdepth," + monBd + ",vrr," + monVrr + ",cm," + monCm;
    }
    return arg;
}

// Builds structured output data for one Hyprland monitor.
// Returns { steps: [{argv, delayAfter?}], batchArg: string|null } or null.
function buildOutputCmd(mon, monRes, monHz, monScale, monPosX, monPosY,
                        isSelected, selParams, savedConfig) {
    var savedMon = savedConfig[mon.name] || {};

    var monHdr     = isSelected ? selParams.hdr      : (savedMon.hdr      !== undefined ? savedMon.hdr      : (mon.hdr      || false));
    var monBd      = isSelected ? selParams.bitdepth : (savedMon.bitdepth !== undefined ? savedMon.bitdepth : (mon.bitdepth || 8));
    var monVrr     = isSelected ? selParams.vrr      : (savedMon.vrr      !== undefined ? savedMon.vrr      : (mon.vrr      || 0));
    var monSdrLum  = isSelected ? selParams.sdrLuminance  : (savedMon.sdrLuminance  !== undefined ? savedMon.sdrLuminance  : ((mon.sdrLuminance  !== undefined) ? mon.sdrLuminance  : 450));
    var monSdrBri  = isSelected ? selParams.sdrBrightness : (savedMon.sdrBrightness !== undefined ? savedMon.sdrBrightness : (mon.sdrBrightness || 1.0));
    var monSdrSat  = isSelected ? selParams.sdrSaturation : (savedMon.sdrSaturation !== undefined ? savedMon.sdrSaturation : (mon.sdrSaturation || 1.0));
    var monCm      = isSelected ? selParams.colorManagement : (savedMon.colorManagement !== undefined ? savedMon.colorManagement : (mon.colorManagement || "srgb"));
    var monEotf    = isSelected ? selParams.sdrEotf  : (savedMon.sdrEotf  !== undefined ? savedMon.sdrEotf  : ((mon.sdrEotf !== undefined) ? mon.sdrEotf : 1));

    if (isRiskyColorMode(monCm)) monVrr = 0;

    var changed = monitorSettingChanged(mon, monRes, monHz, monScale, monPosX, monPosY,
                                        monHdr, monBd, monVrr, monSdrLum, monSdrBri, monSdrSat, monCm, monEotf);
    if (!isSelected && !changed) return null;

    var monitorArg = buildMonitorArg(mon.name, monRes, monHz, monPosX, monPosY, monScale,
                                     monHdr, monBd, monVrr, monSdrBri, monSdrSat, monCm);

    var needsCmReset = isSelected && monCm !== (mon.colorManagement || "srgb");
    if (needsCmReset) {
        var resetArg = mon.name + "," + monRes + "@" + monHz + "," + monPosX + "x" + monPosY + "," + monScale + ",bitdepth,10,vrr,0,cm,srgb";
        return {
            steps: [
                { argv: ["hyprctl", "keyword", "monitor", resetArg], delayAfter: 200 },
                { argv: ["hyprctl", "keyword", "monitor", monitorArg] }
            ],
            batchArg: null
        };
    }

    return { steps: [], batchArg: "keyword monitor " + monitorArg };
}

// Assembles all per-output results into a flat step queue.
// Returns array of { argv: [...], delayAfter?: number }.
function assembleSteps(cmds, defaultOutputName) {
    var steps     = [];
    var batchArgs = [];

    for (var i = 0; i < cmds.length; i++) {
        for (var j = 0; j < cmds[i].steps.length; j++) {
            steps.push(cmds[i].steps[j]);
        }
        if (cmds[i].batchArg) batchArgs.push(cmds[i].batchArg);
    }

    if (batchArgs.length > 0) {
        if (defaultOutputName) batchArgs.push("dispatch focusmonitor " + defaultOutputName);
        steps.push({ argv: ["hyprctl", "--batch", batchArgs.join(" ; ")] });
    } else if (defaultOutputName) {
        steps.push({ argv: ["hyprctl", "dispatch", "focusmonitor", defaultOutputName] });
    }

    return steps;
}
