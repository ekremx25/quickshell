import QtQuick
import Quickshell.Io

// Dosya değişikliklerini izler.
//
// ── İNOTIFY MODU (inotify-tools kuruluysa) ──────────────────────────
//   inotifywait ile dizini dinler; close_write veya moved_to olayında
//   değişikliği bildirir. CPU kullanımı sıfır — timer yok, polling yok.
//   Atomik mv yazmaları (TextDataStore) da doğru şekilde yakalanır.
//
// ── POLLING MODU (inotify-tools yoksa otomatik devreye girer) ────────
//   stat ile mtime/size/inode üçlüsü karşılaştırılır. İlk çalışmada
//   baseline alınır; sahte "changed" sinyali üretilmez.
//
// inotify-tools kurmak için (Arch): sudo pacman -S inotify-tools
// Kurulduktan sonra herhangi bir config değişikliği uygulamak yeterli.
Item {
    id: root

    visible: false
    width: 0
    height: 0

    property string path: ""
    property bool active: true
    // interval yalnızca polling fallback modunda kullanılır
    property int interval: 1000

    signal changed()

    // inotifywait bulunamazsa (exit 127) true yapılır, polling başlar
    property bool _pollingMode: false
    property string _lastToken: ""
    property bool _initialized: false

    function shellQuote(text) {
        return "'" + String(text).replace(/'/g, "'\\''") + "'";
    }

    // path'in bulunduğu dizini döndür
    function _dir() {
        var idx = path.lastIndexOf("/");
        return idx > 0 ? path.substring(0, idx) : ".";
    }

    // path'in dosya adını döndür
    function _file() {
        var idx = path.lastIndexOf("/");
        return idx >= 0 ? path.substring(idx + 1) : path;
    }

    // ----------------------------------------------------------------
    // inotifywait tabanlı izleme (event-driven)
    // ----------------------------------------------------------------
    Process {
        id: watchProc
        running: root.active && root.path.length > 0 && !root._pollingMode
        // Dizini izle; moved_to atomik mv yazmaları da yakalar
        command: root.path.length > 0 ? [
            "sh", "-c",
            "exec inotifywait -m -q -e close_write,moved_to --format '%f' "
                + root.shellQuote(root._dir())
        ] : []

        stdout: SplitParser {
            onRead: data => {
                // Sadece izlediğimiz dosya değiştiyse sinyal ver
                if (data.trim() === root._file()) {
                    root.changed();
                }
            }
        }

        onExited: exitCode => {
            if (!root.active) return;
            if (exitCode === 127) {
                // inotifywait bulunamadı → polling moduna geç
                root._pollingMode = true;
                return;
            }
            // Geçici hata (dizin yeniden oluştu, compositor restart vb.)
            // 1 saniye sonra yeniden dene
            inotifyRestartTimer.restart();
        }
    }

    Timer {
        id: inotifyRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.active && root.path.length > 0 && !root._pollingMode) {
                watchProc.running = true;
            }
        }
    }

    // ----------------------------------------------------------------
    // Polling fallback (inotify-tools kurulu değilse)
    // ----------------------------------------------------------------
    Timer {
        id: pollTimer
        interval: root.interval
        running: root.active && root._pollingMode
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!statProc.running && root.path.length > 0) {
                statProc.output = "";
                statProc.running = true;
            }
        }
    }

    Process {
        id: statProc
        command: root.path.length > 0 ? [
            "sh", "-c",
            "if test -e " + root.shellQuote(root.path) + "; then "
                + "stat -Lc '%Y:%s:%i' " + root.shellQuote(root.path) + " 2>/dev/null "
                + "|| stat -c '%Y:%s:%i' " + root.shellQuote(root.path) + " 2>/dev/null "
                + "|| echo present; "
                + "else echo missing; fi"
        ] : []
        running: false
        property string output: ""
        stdout: SplitParser { onRead: data => { statProc.output += data; } }
        onExited: {
            var token = statProc.output.trim();
            statProc.output = "";
            if (token.length === 0) return;
            // İlk çalışmada baseline kur; sahte "changed" üretme
            if (!root._initialized) {
                root._lastToken = token;
                root._initialized = true;
                return;
            }
            if (token !== root._lastToken) {
                root._lastToken = token;
                root.changed();
            }
        }
    }
}
