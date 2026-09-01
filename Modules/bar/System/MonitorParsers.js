.pragma library

// Pure output-parsing functions for each compositor.
// Each function takes raw command output text and returns an array of output objects.
// Overlay and finalization are handled by MonitorsBackend after parsing.

function parseHyprlandOutputs(text) {
    var data = JSON.parse(text);
    var outs = [];
    for (var i = 0; i < data.length; i++) {
        var info = data[i];
        var outObj = {
            name: info.name,
            make: info.make || "",
            model: info.model || "",
            serial: info.serial || "",
            description: info.description || "",
            desc: (info.make || "") + " " + (info.model || ""),
            physicalWidth: info.physicalWidth || 0,
            physicalHeight: info.physicalHeight || 0,
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
            iccProfile: info.iccProfile || info.icc || "",
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
        outs.push(outObj);
    }
    return outs;
}

function parseNiriOutputs(text) {
    var data = JSON.parse(text);
    var outs = [];
    var keys = Object.keys(data);
    for (var i = 0; i < keys.length; i++) {
        var name = keys[i];
        var info = data[name];
        var outObj = {
            name: name,
            desc: (info.make || "") + " " + (info.model || ""),
            physicalWidth: info.physical_size ? (info.physical_size.width || 0) : 0,
            physicalHeight: info.physical_size ? (info.physical_size.height || 0) : 0,
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
        outs.push(outObj);
    }
    return outs;
}

function _snapMangoDimension(value) {
    var rounded = Math.round(value);
    var common = [
        480, 576, 600, 720, 768, 800, 900, 1024, 1050, 1080, 1200,
        1280, 1366, 1440, 1600, 1620, 1800, 1920, 2160, 2560, 2880,
        3200, 3440, 3840, 4096, 5120, 7680
    ];
    var closest = rounded;
    var distance = Number.MAX_VALUE;
    for (var i = 0; i < common.length; i++) {
        var candidateDistance = Math.abs(common[i] - rounded);
        if (candidateDistance < distance) {
            distance = candidateDistance;
            closest = common[i];
        }
    }
    return distance <= Math.max(4, rounded * 0.002) ? closest : rounded;
}

function _parseMangoJsonOutputs(text) {
    var data = JSON.parse(text);
    var monitors = Array.isArray(data) ? data : (data.monitors || []);
    var outs = [];

    for (var i = 0; i < monitors.length; i++) {
        var info = monitors[i] || {};
        if (!info.name) continue;

        var scale = parseFloat(info.scale);
        if (!isFinite(scale) || scale <= 0) scale = 1;

        // Mango's IPC reports logical geometry. Rebuild the physical mode from
        // logical size × scale and tolerate the one-pixel rounding used by
        // fractional scaling (for example 2888 × 1.33 -> 3840).
        var physicalWidth = _snapMangoDimension((Number(info.width) || 0) * scale);
        var physicalHeight = _snapMangoDimension((Number(info.height) || 0) * scale);
        var res = physicalWidth + "x" + physicalHeight;
        var refreshValue = info.refresh_rate !== undefined ? info.refresh_rate : info.refresh;
        var refresh = parseFloat(refreshValue);
        if (!isFinite(refresh) || refresh <= 0) refresh = 60;
        var hz = refresh.toFixed(3);

        outs.push({
            name: info.name,
            make: "",
            model: "",
            serial: "",
            description: info.name,
            desc: info.name,
            physicalWidth: 0,
            physicalHeight: 0,
            res: res,
            hz: hz,
            scale: scale.toFixed(2),
            posX: Math.round(Number(info.x) || 0),
            posY: Math.round(Number(info.y) || 0),
            isDefault: false,
            hdr: !!info.is_hdr,
            bitdepth: info.is_hdr ? 10 : 8,
            vrr: info.is_vrr ? 1 : 0,
            colorManagement: info.is_hdr ? "hdr" : "srgb",
            modes: [{ res: res, hz: hz, current: true }]
        });
    }
    return outs;
}

function _parseMangoRandrOutputs(text) {
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
                physicalWidth: 0,
                physicalHeight: 0,
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
        if (trimmed === "Modes:") { inModes = true; continue; }

        if (inModes && trimmed.indexOf("px,") > 0) {
            var modeMatch = trimmed.match(/(\d+)x(\d+)\s+px,\s+([\d.]+)\s+Hz(.*)/);
            if (modeMatch) {
                var res = modeMatch[1] + "x" + modeMatch[2];
                var hz = parseFloat(modeMatch[3]).toFixed(3);
                var isCurrent = (modeMatch[4] || "").indexOf("current") >= 0;
                current.modes.push({ res: res, hz: hz, current: isCurrent });
                if (isCurrent) { current.res = res; current.hz = hz; }
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
    if (current) outs.push(current);
    return outs;
}

function parseMangoOutputs(text) {
    var trimmed = String(text || "").trim();
    if (trimmed.length === 0) return [];
    if (trimmed[0] === "{" || trimmed[0] === "[") return _parseMangoJsonOutputs(trimmed);
    return _parseMangoRandrOutputs(text);
}
