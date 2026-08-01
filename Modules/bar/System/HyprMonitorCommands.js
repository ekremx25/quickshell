.pragma library

// Color mode classification — kept here so MonitorsBackend can delegate
// isHdrColorMode / isRiskyColorMode to this library.
var RISKY_COLOR_MODES = ["dcip3", "dp3", "adobe"];
var HDR_COLOR_MODES   = ["hdr", "hdredid", "hdrp3", "hdrapple", "hdradobe"];

function isRiskyColorMode(mode) { return RISKY_COLOR_MODES.indexOf(mode) >= 0; }
function isHdrColorMode(mode)   { return HDR_COLOR_MODES.indexOf(mode) >= 0; }

function normalizeSdrEotf(value) {
    if (value === 0 || value === "0") return "default";
    if (value === 1 || value === "1") return "srgb";
    if (value === 2 || value === "2") return "gamma22";
    return value;
}

// Returns true when any Hyprland-specific setting differs from the live output.
function monitorSettingChanged(mon, monRes, monHz, monScale, monPosX, monPosY,
                               monHdr, monBitdepth, monVrr, monSdrLum, monSdrBri,
                               monSdrSat, monCm, monEotf, monIcc) {
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
    if (monIcc) return true;
    if (monCm    !== (mon.colorManagement || "srgb")) return true;
    if (monEotf  !== ((mon.sdrEotf !== undefined) ? mon.sdrEotf : 1)) return true;
    return false;
}

// Builds the monitor argument string for hyprctl keyword monitor.
function buildMonitorArg(monName, monRes, monHz, monPosX, monPosY, monScale,
                         monHdr, monBd, monVrr, monSdrLum, monSdrBri, monSdrSat, monCm, monEotf, monIcc) {
    var arg = monName + "," + monRes + "@" + monHz + "," + monPosX + "x" + monPosY + "," + monScale;
    monEotf = normalizeSdrEotf(monEotf);
    if (monIcc) {
        arg += ",bitdepth," + monBd + ",vrr," + monVrr + ",icc," + monIcc + ",sdrbrightness," + monSdrBri.toFixed(1) + ",sdrsaturation," + monSdrSat.toFixed(1) + ",sdr_max_luminance," + Math.round(monSdrLum);
    } else if (monHdr || isHdrColorMode(monCm)) {
        var appliedCm = (monCm === "hdredid") ? "hdredid" : "hdr";
        arg += ",bitdepth," + monBd + ",vrr," + monVrr + ",cm," + appliedCm + ",sdrbrightness," + monSdrBri.toFixed(1) + ",sdrsaturation," + monSdrSat.toFixed(1) + ",sdr_max_luminance," + Math.round(monSdrLum);
    } else if (monCm === "default") {
        arg += ",bitdepth," + monBd + ",vrr," + monVrr;
    } else {
        arg += ",bitdepth," + monBd + ",vrr," + monVrr + ",cm," + monCm;
    }
    if (monEotf === "default" || monEotf === "gamma22" || monEotf === "srgb") {
        arg += ",sdr_eotf," + monEotf;
    }
    return arg;
}

// Builds structured output data for one Hyprland monitor.
// Returns { steps: [{argv, delayAfter?}], batchArg: string|null } or null.
function buildOutputCmd(mon, monRes, monHz, monScale, monPosX, monPosY,
                        isSelected, selParams, savedConfig, forceApply, helperPath) {
    var savedMon = savedConfig[mon.name] || {};

    var monHdr     = isSelected ? selParams.hdr      : (savedMon.hdr      !== undefined ? savedMon.hdr      : (mon.hdr      || false));
    var monBd      = isSelected ? selParams.bitdepth : (savedMon.bitdepth !== undefined ? savedMon.bitdepth : (mon.bitdepth || 8));
    var monVrr     = isSelected ? selParams.vrr      : (savedMon.vrr      !== undefined ? savedMon.vrr      : (mon.vrr      || 0));
    var monSdrLum  = isSelected ? selParams.sdrLuminance  : (savedMon.sdrLuminance  !== undefined ? savedMon.sdrLuminance  : ((mon.sdrLuminance  !== undefined) ? mon.sdrLuminance  : 450));
    var monSdrBri  = isSelected ? selParams.sdrBrightness : (savedMon.sdrBrightness !== undefined ? savedMon.sdrBrightness : (mon.sdrBrightness || 1.0));
    var monSdrSat  = isSelected ? selParams.sdrSaturation : (savedMon.sdrSaturation !== undefined ? savedMon.sdrSaturation : (mon.sdrSaturation || 1.0));
    var monCm      = isSelected ? selParams.colorManagement : (savedMon.colorManagement !== undefined ? savedMon.colorManagement : (mon.colorManagement || "srgb"));
    var monEotf    = isSelected ? selParams.sdrEotf  : (savedMon.sdrEotf  !== undefined ? savedMon.sdrEotf  : ((mon.sdrEotf !== undefined) ? mon.sdrEotf : 1));
    var monIcc     = isSelected ? (selParams.iccProfile || "") : (savedMon.iccProfile !== undefined ? savedMon.iccProfile : (mon.iccProfile || ""));

    if (isRiskyColorMode(monCm)) monVrr = 0;

    var changed = monitorSettingChanged(mon, monRes, monHz, monScale, monPosX, monPosY,
                                        monHdr, monBd, monVrr, monSdrLum, monSdrBri, monSdrSat, monCm, monEotf, monIcc);
    // A neighbouring output may have been moved by the layout reflow after
    // the selected output changed scale/resolution. In that case `mon`
    // already contains the new coordinates, so the normal comparison cannot
    // detect the move. forceApply ensures the compositor receives it.
    if (!isSelected && !changed && !forceApply) return null;

    var monitorArg = buildMonitorArg(mon.name, monRes, monHz, monPosX, monPosY, monScale,
                                     monHdr, monBd, monVrr, monSdrLum, monSdrBri, monSdrSat, monCm, monEotf, monIcc);

    var needsCmReset = isSelected && monCm !== (mon.colorManagement || "srgb");
    if (needsCmReset) {
        var resetArg = mon.name + "," + monRes + "@" + monHz + "," + monPosX + "x" + monPosY + "," + monScale + ",bitdepth,10,vrr,0,cm,srgb";
        return {
            steps: [
                { argv: [helperPath, "monitor", resetArg], delayAfter: 200 },
                { argv: [helperPath, "monitor", monitorArg] }
            ],
            batchArg: null
        };
    }

    return { steps: [{ argv: [helperPath, "monitor", monitorArg] }], batchArg: null };
}

// Assembles all per-output results into a flat step queue.
// Returns array of { argv: [...], delayAfter?: number }.
function assembleSteps(cmds, defaultOutputName, helperPath) {
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
        steps.push({ argv: [helperPath, "focus", defaultOutputName] });
    }

    return steps;
}
