.pragma library

var DEBUG_ENABLED = false;

function setDebugEnabled(enabled) {
    DEBUG_ENABLED = !!enabled;
}

function debug(scope, message) {
    if (!DEBUG_ENABLED) return;
    console.log("[" + scope + "] " + message);
}

function warn(scope, message) {
    console.warn("[" + scope + "] " + message);
}

function error(scope, message) {
    console.error("[" + scope + "] " + message);
}
