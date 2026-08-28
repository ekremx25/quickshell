.pragma library

// Fallback only. Runtime bar changes are saved to the quickshell config directory.

function createWorkspacesConfig() {
    return {
        "format": "roman",
        "style": "square",
        "transparent": true,
        "displayMode": "role",
        "workspaceCount": 5,
        "showEmpty": true,
        "showSpecial": true,
        "showApps": true,
        "groupApps": true,
        "scrollEnabled": true,
        "wrapAround": true,
        "reverseScroll": false,
        "iconSize": 20,
        "maxIcons": 4
    };
}

function _boolean(value, fallback) {
    return typeof value === "boolean" ? value : fallback;
}

function _integer(value, fallback, minimum, maximum) {
    var parsed = Number(value);
    if (!isFinite(parsed)) return fallback;
    return Math.max(minimum, Math.min(maximum, Math.round(parsed)));
}

function _choice(value, allowed, fallback) {
    return allowed.indexOf(value) >= 0 ? value : fallback;
}

function normalizeWorkspacesConfig(config) {
    var defaults = createWorkspacesConfig();
    var source = config && typeof config === "object" ? config : {};

    return {
        format: _choice(source.format, ["chinese", "roman", "arabic"], defaults.format),
        style: _choice(source.style, ["square", "circle", "outline", "underline", "overline", "pipe", "dot"], defaults.style),
        transparent: _boolean(source.transparent, defaults.transparent),
        displayMode: _choice(source.displayMode, ["role", "occupied", "global"], defaults.displayMode),
        workspaceCount: _integer(source.workspaceCount, defaults.workspaceCount, 1, 20),
        showEmpty: _boolean(source.showEmpty, defaults.showEmpty),
        showSpecial: _boolean(source.showSpecial, defaults.showSpecial),
        showApps: _boolean(source.showApps, defaults.showApps),
        groupApps: _boolean(source.groupApps, defaults.groupApps),
        scrollEnabled: _boolean(source.scrollEnabled, defaults.scrollEnabled),
        wrapAround: _boolean(source.wrapAround, defaults.wrapAround),
        reverseScroll: _boolean(source.reverseScroll, defaults.reverseScroll),
        iconSize: _integer(source.iconSize, defaults.iconSize, 10, 36),
        maxIcons: _integer(source.maxIcons, defaults.maxIcons, 1, 12)
    };
}

function createBarConfig() {
    return {
        left: ["Launcher","RamModule","SysInfoGroup","CurrencyConverter"],
        center: ["Workspaces","Notifications","Notepad"],
        right: ["Equalizer","Volume","Clipboard","PowerGroup"],
        inactive: ["NightLight"],
        workspaces: createWorkspacesConfig(),
        theme: "",
        barPosition: "top",
        moduleSchemaVersion: 3
    };
}

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}
