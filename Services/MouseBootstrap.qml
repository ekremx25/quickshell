import QtQuick
import Quickshell
import Quickshell.Io
import "./core" as Core
import "./core/Log.js" as Log

Item {
    id: root

    visible: false
    width: 0
    height: 0

    readonly property bool supported: CompositorService.isHyprland || CompositorService.isMango
    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/quickshell/mouse_config.json"
    readonly property string applyScriptPath: (Quickshell.env("HOME") || "") + "/.config/quickshell/scripts/hypr_input_apply.sh"

    property real sensitivity: 0.0
    property real scrollFactor: 1.0
    property string accelProfile: "adaptive"
    property string cursorTheme: Quickshell.env("XCURSOR_THEME") || "Adwaita"
    property int cursorSize: parseInt(Quickshell.env("XCURSOR_SIZE") || "24")
    property bool applyMouseSettings: false

    function saneCursorTheme(theme) {
        var name = String(theme || "").trim()
        if (name.length === 0 || name.length > 96) return (Quickshell.env("XCURSOR_THEME") || "Adwaita")
        var cursorTokenCount = (name.match(/cursors/g) || []).length
        if (cursorTokenCount > 1) return (Quickshell.env("XCURSOR_THEME") || "Adwaita")
        return name
    }

    Timer {
        id: applyDelay
        interval: 1400
        repeat: false
        running: false
        onTriggered: {
            if (root.supported && root.applyMouseSettings) runtimeApplyProc.running = true
        }
    }

    Core.JsonDataStore {
        id: configStore
        path: root.configPath
        defaultValue: ({
            sensitivity: 0.0,
            scrollFactor: 1.0,
            accelProfile: "adaptive",
            cursorTheme: Quickshell.env("XCURSOR_THEME") || "Adwaita",
            cursorSize: parseInt(Quickshell.env("XCURSOR_SIZE") || "24"),
            managedByQuickshell: false
        })
        onLoadedValue: function(cfg) {
            root.sensitivity = cfg.sensitivity !== undefined ? cfg.sensitivity : 0.0
            root.scrollFactor = cfg.scrollFactor !== undefined ? cfg.scrollFactor : 1.0
            root.accelProfile = cfg.accelProfile || "adaptive"
            root.cursorTheme = root.saneCursorTheme(cfg.cursorTheme || root.cursorTheme)
            root.cursorSize = cfg.cursorSize !== undefined ? cfg.cursorSize : root.cursorSize
            root.applyMouseSettings = cfg.managedByQuickshell === true
            applyDelay.restart()
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("MouseBootstrap", "Config parse error: " + details)
        }
    }

    Component.onCompleted: configStore.load()

    Process {
        id: runtimeApplyProc
        command: [
            root.applyScriptPath,
            Number(root.sensitivity).toFixed(2),
            Number(root.scrollFactor).toFixed(2),
            root.accelProfile,
            root.saneCursorTheme(root.cursorTheme),
            String(root.cursorSize),
            CompositorService.compositor
        ]
    }
}
