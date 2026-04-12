import QtQuick
import Quickshell.Io
import "../../../Services/core" as Core

// VPN panelini dış süreçlerden tetiklemek için IPC servisi.
//
// Tetikleme mekanizması:
//   Herhangi bir process $XDG_RUNTIME_DIR'e "qs_vpn_open" dosyası oluşturduğunda
//   triggerDetected() sinyali yayınlanır ve dosya silinir.
//
// inotifywait varsa (inotify-tools):
//   Dizin create olayı izlenir — polling yoktur, CPU maliyeti sıfır.
// Yoksa:
//   600ms fallback polling devreye girer (önceki davranış korunur).
Item {
    id: service
    visible: false; width: 0; height: 0

    signal triggerDetected()

    readonly property string triggerPath:        Core.PathService.runtimePath("qs_vpn_open")
    readonly property string refreshTriggerPath: Core.PathService.runtimePath("qs_vpn_refresh")

    function shellQuote(text) {
        return "'" + String(text).replace(/'/g, "'\\''") + "'";
    }

    // Runtime dizinini hesapla (dirname)
    function _runtimeDir() {
        var idx = triggerPath.lastIndexOf("/");
        return idx > 0 ? triggerPath.substring(0, idx) : "/tmp";
    }

    function notifyNetworkRefresh() {
        refreshTriggerProc.running = true;
    }

    // ----------------------------------------------------------------
    // inotifywait tabanlı izleme (event-driven, CPU-free)
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
                // inotifywait bulunamadı → polling fallback
                service._pollingMode = true;
                return;
            }
            // Geçici hata: 1 saniye sonra yeniden dene
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
    // Polling fallback (inotify-tools kurulu değilse)
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
    // Yardımcı process'ler
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
