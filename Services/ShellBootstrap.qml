import QtQuick
import Quickshell.Io
import Quickshell

Item {
    id: root

    visible: false
    width: 0
    height: 0

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")
    readonly property string monitorScriptPath: configHome + "/quickshell/scripts/apply_monitors.sh"

    Timer {
        id: monitorApplyDelay
        interval: 2000
        running: true
        repeat: false
        onTriggered: monitorApplyProc.running = true
    }

    Process {
        id: monitorApplyProc
        command: [root.monitorScriptPath]
        running: false
    }
}
