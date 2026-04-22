.pragma library

// Set DEBUG_ENABLED = true to enable debug() output.
// Leave false in production — warn/error always print.
var DEBUG_ENABLED = false;

function setDebugEnabled(enabled) {
    DEBUG_ENABLED = !!enabled;
}

// Verbose development info. Suppressed when DEBUG_ENABLED is false.
function debug(scope, message) {
    if (!DEBUG_ENABLED) return;
    console.log("[DBG][" + scope + "] " + message);
}

// Expected, noteworthy events (service startup, config load, etc.).
function info(scope, message) {
    console.log("[INF][" + scope + "] " + message);
}

// Unexpected but recoverable conditions.
function warn(scope, message) {
    console.warn("[WRN][" + scope + "] " + message);
}

// Critical errors.
function error(scope, message) {
    console.error("[ERR][" + scope + "] " + message);
}
