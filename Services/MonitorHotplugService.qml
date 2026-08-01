import QtQuick
import Quickshell
import Quickshell.Io
import "./core/Log.js" as Log

Item {
    id: root
    visible: false
    width: 0
    height: 0

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")
    readonly property string eventScript: configHome + "/quickshell/scripts/hypr_events.sh"
    readonly property string roleManager: configHome + "/quickshell/scripts/monitor_role_manager.py"

    function scheduleApply() {
        applyDebounce.restart();
    }

    Process {
        id: eventProc
        command: [root.eventScript]
        running: CompositorService.isHyprland
        stdout: SplitParser {
            onRead: data => {
                var line = String(data || "").trim();
                if (line.indexOf("monitoradded") === 0 || line.indexOf("monitorremoved") === 0) {
                    root.scheduleApply();
                }
            }
        }
        onExited: {
            if (CompositorService.isHyprland) reconnectTimer.restart();
        }
    }

    Timer {
        id: reconnectTimer
        interval: 1000
        repeat: false
        onTriggered: if (!eventProc.running && CompositorService.isHyprland) eventProc.running = true
    }

    Timer {
        id: applyDebounce
        interval: 800
        repeat: false
        onTriggered: {
            if (applyProc.running) {
                root.applyAgain = true;
            } else {
                applyProc.running = true;
            }
        }
    }

    property bool applyAgain: false

    Process {
        id: applyProc
        command: [root.roleManager]
        running: false
        stdout: SplitParser { onRead: data => Log.debug("MonitorHotplug", data) }
        stderr: SplitParser { onRead: data => Log.warn("MonitorHotplug", data) }
        onExited: {
            CompositorService.refreshMonitors();
            if (root.applyAgain) {
                root.applyAgain = false;
                applyDebounce.restart();
            }
        }
    }
}
