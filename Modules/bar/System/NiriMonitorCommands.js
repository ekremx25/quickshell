.pragma library

// Builds a direct-argv step for applying one Niri output configuration.
// Uses the external niri_apply.py script with env vars passed via the
// `env` command — no shell invocation needed.
function buildOutputStep(monName, newMode, monPosX, monPosY, monScale, scriptPath) {
    return {
        argv: [
            "env",
            "NIRI_MON="  + monName,
            "NIRI_MODE=" + newMode,
            "NIRI_PX="   + String(monPosX),
            "NIRI_PY="   + String(monPosY),
            "NIRI_SC="   + String(monScale),
            "python3", scriptPath
        ]
    };
}
