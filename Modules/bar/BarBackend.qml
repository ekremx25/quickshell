import QtQuick
import Qt.labs.platform
import Quickshell
import "BarDefaults.js" as BarDefaults
import "../../Services" as S
import "../../Services/core" as Core
import "../../Services/core/Log.js" as Log

Item {
    id: backend

    readonly property var initialBarConfig: BarDefaults.createBarConfig()

    property var barLayout: ({
        left: initialBarConfig.left.slice(),
        center: initialBarConfig.center.slice(),
        right: initialBarConfig.right.slice(),
        workspaces: BarDefaults.clone(initialBarConfig.workspaces)
    })
    property string barPosition: initialBarConfig.barPosition || "top"
    property bool isVertical: barPosition === "left" || barPosition === "right"
    property var workspacesConfig: barLayout.workspaces || BarDefaults.createWorkspacesConfig()
    property bool configLoaded: false
    readonly property string configDir: StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell"
    readonly property string configPath: configDir + "/bar_config.json"
    property string lastConfigContent: ""

    function normalizeLayout(cfg) {
        var normalized = BarDefaults.clone(cfg || initialBarConfig);
        if (!Array.isArray(normalized.left)) normalized.left = initialBarConfig.left.slice();
        if (!Array.isArray(normalized.center)) normalized.center = initialBarConfig.center.slice();
        if (!Array.isArray(normalized.right)) normalized.right = initialBarConfig.right.slice();
        if (!normalized.workspaces) normalized.workspaces = BarDefaults.createWorkspacesConfig();
        if (!normalized.barPosition) normalized.barPosition = initialBarConfig.barPosition || "top";
        return normalized;
    }

    function applyConfig(cfg) {
        var normalized = normalizeLayout(cfg);
        if (normalized.barPosition) {
            backend.barPosition = normalized.barPosition;
        }
        backend.barLayout = normalized;
        backend.workspacesConfig = normalized.workspaces;
        backend.configLoaded = true;
        if (normalized.theme && normalized.theme.name) {
            Theme.setTheme(normalized.theme.name);
        }
    }

    function refreshConfig() {
        configStore.load();
    }

    Component.onCompleted: backend.refreshConfig()

    Core.JsonDataStore {
        id: configStore
        path: backend.configPath
        defaultValue: backend.initialBarConfig
        onLoadedValue: function(cfg, rawText) {
            var content = rawText.trim();
            if (content.length === 0) {
                var seeded = backend.normalizeLayout(backend.initialBarConfig);
                backend.lastConfigContent = JSON.stringify(seeded, null, 2);
                backend.applyConfig(seeded);
                configStore.save(seeded);
                return;
            }
            if (content === backend.lastConfigContent && backend.configLoaded) return;
            backend.lastConfigContent = content;
            backend.applyConfig(cfg);
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("BarBackend", "Config parse error: " + details);
        }
    }

    Core.FileChangeWatcher {
        path: backend.configPath
        interval: 500
        onChanged: backend.refreshConfig()
    }
}
