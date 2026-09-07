// Keep the environment-only rules aligned with scripts/detect_compositor.sh.
// The regression test compares both implementations on the same sessions.
function fromEnvironment(desktop, session, niri, mango, hyprland) {
    var names = String(desktop || "").toLowerCase().split(":");
    var selected = String(session || "").toLowerCase();
    var candidates = ["niri", "mango", "hyprland"];
    for (var i = 0; i < candidates.length; i++) {
        if (names.indexOf(candidates[i]) >= 0 || (!desktop && selected === candidates[i])) return candidates[i];
    }
    if (desktop || session) return "unknown";
    var hints = [niri, mango, hyprland];
    var found = [];
    for (var j = 0; j < hints.length; j++) if (hints[j]) found.push(candidates[j]);
    return found.length === 1 ? found[0] : "unknown";
}
