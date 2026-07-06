import QtQuick
import Quickshell.Io
import "../../../Services/core" as Core

// IPC service for triggering the VPN panel from external processes.
//
// Trigger mechanism:
//   When any process creates a "qs_vpn_open" file in $XDG_RUNTIME_DIR,
//   the triggerDetected() signal is emitted and the file is deleted.
//
// If inotifywait is available (inotify-tools):
//   Directory create events are watched — no polling, zero CPU cost.
// Otherwise:
//   600ms fallback polling kicks in (preserves prior behavior).
Item {
    id: service
    visible: false; width: 0; height: 0

    signal triggerDetected()

    readonly property string triggerPath:        Core.PathService.runtimePath("qs_vpn_open")
    readonly property string refreshTriggerPath: Core.PathService.runtimePath("qs_vpn_refresh")

    function shellQuote(text) {
        return "'" + String(text).replace(/'/g, "'\\''") + "'";
    }

    // Compute the runtime directory (dirname)
    function _runtimeDir() {
        var idx = triggerPath.lastIndexOf("/");
        return idx > 0 ? triggerPath.substring(0, idx) : "/tmp";
    }

    function notifyNetworkRefresh() {
        refreshTriggerProc.running = true;
    }

    // ----------------------------------------------------------------
    // inotifywait-based watching (event-driven, CPU-free)
    // ----------------------------------------------------------------
    property bool _pollingMode: false

    Process {
        id: watchProc
        running: !service._pollingMode
        command: [
            "sh", "-c",
            "exec inotifywait -m -q -e create --format '%f' "
                + service.shellQuote(service._runtimeDir())
        ]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "qs_vpn_open") {
                    triggerRemoveProc.running = true;
                    service.triggerDetected();
                }
            }
        }
        onExited: exitCode => {
            if (exitCode === 127) {
                // inotifywait not found → polling fallback
                service._pollingMode = true;
                return;
            }
            // Temporary error: retry after 1 second
            restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 1000; repeat: false
        onTriggered: {
            if (!service._pollingMode) watchProc.running = true;
        }
    }

    // ----------------------------------------------------------------
    // Polling fallback (if inotify-tools is not installed)
    // ----------------------------------------------------------------
    Timer {
        id: fallbackTimer
        interval: 600
        running: service._pollingMode
        repeat: true
        onTriggered: {
            triggerCheckProc.running = false;
            triggerCheckProc.running = true;
        }
    }

    Process {
        id: triggerCheckProc
        command: ["/usr/bin/test", "-f", service.triggerPath]
        onExited: function(exitCode) {
            if (exitCode === 0) {
                triggerRemoveProc.running = true;
                service.triggerDetected();
            }
        }
    }

    // ----------------------------------------------------------------
    // Helper processes
    // ----------------------------------------------------------------
    Process {
        id: triggerRemoveProc
        command: ["/usr/bin/rm", "-f", service.triggerPath]
    }

    Process {
        id: refreshTriggerProc
        command: ["/usr/bin/touch", service.refreshTriggerPath]
    }
}
