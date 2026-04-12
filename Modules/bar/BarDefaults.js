.pragma library

// Fallback only. Runtime bar changes are saved to the quickshell config directory.

function createWorkspacesConfig() {
    return {
        "format": "roman",
        "style": "underline",
        "transparent": true,
        "showApps": true,
        "groupApps": true,
        "scrollEnabled": true,
        "iconSize": 20
    };
}

function createBarConfig() {
    return {
        left: ["Launcher","Calendar","RamModule","SysInfoGroup"],
        center: ["Workspaces","Notifications","Notepad"],
        right: ["Equalizer","Volume","Clipboard","PowerGroup"],
        inactive: [],
        workspaces: createWorkspacesConfig(),
        theme: "",
        barPosition: "top"
    };
}

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}
