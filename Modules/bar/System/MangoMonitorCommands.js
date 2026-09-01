.pragma library

// A scale change belongs to one output. Neighbouring outputs only need a new
// rule when reflow moved their position to keep the layout attached.
function shouldApplyOutput(isSelected, layoutChanged) {
    return !!isSelected || !!layoutChanged;
}

// Builds a direct-argv step for the validated, atomic Mango config writer.
function buildOutputSteps(monName, monRes, monHz, monPosX, monPosY, monScale, options, applyScriptPath) {
    var opts = options || {};
    return [{
        argv: [
            applyScriptPath,
            "set",
            String(monName),
            String(monRes),
            String(monHz),
            String(monPosX),
            String(monPosY),
            String(monScale),
            String(opts.vrr ? 1 : 0),
            String(opts.hdr ? 1 : 0)
        ]
    }];
}
