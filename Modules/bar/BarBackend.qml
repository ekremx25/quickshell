import QtQuick
import Qt.labs.platform
import Quickshell
import Quickshell.Io
import "../../Widgets"
import "BarDefaults.js" as BarDefaults
import "../../Services" as S
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
        normalized.workspaces = BarDefaults.normalizeWorkspacesConfig(normalized.workspaces);
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

    property string configError: ""

    function refreshConfig() {
        configFile.reload();
    }

    function readConfig(text) {
        var content = text.trim();
        if (!content) {
            configError = "Bar configuration is empty; keeping the current layout.";
            return;
        }
        if (content === lastConfigContent && configLoaded) return;
        try {
            var cfg = JSON.parse(content);
            if (!cfg || typeof cfg !== "object" || Array.isArray(cfg))
                throw new Error("Expected a configuration object");
            backend.applyConfig(cfg);
            backend.lastConfigContent = content;
            backend.configError = "";
        } catch (error) {
            backend.configError = String(error);
            Log.warn("BarBackend", "Bar configuration could not be parsed: " + error);
        }
    }

    // Read directly in Quickshell. Startup must not depend on spawning cat or
    // an inotify process; failed reads must never overwrite saved preferences.
    FileView {
        id: configFile
        path: backend.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: backend.readConfig(text())
        onLoadFailed: function(error) {
            backend.configError = "Could not read bar configuration: " + String(error);
            Log.warn("BarBackend", backend.configError);
        }
    }

}
