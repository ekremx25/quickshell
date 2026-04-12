import QtQuick
import Quickshell.Io

// Dosya okuma/yazma servisi.
//
// Yazma Güvenliği (Atomic Write):
//   Doğrudan hedefe yazmak yerine aynı dizinde geçici bir dosya oluşturur,
//   içeriği oraya yazar ve atomik mv ile hedefe taşır. Böylece:
//     - Shell veya QML çökmesi yarım konfigürasyon bırakmaz.
//     - Okuma ve yazma aynı anda gerçekleşse bile tutarlı veri okunur.
//
// Yazma Sırası (Write Queue):
//   Bir yazma işlemi devam ederken yeni bir write() çağrısı gelirse
//   process öldürülmez; mevcut işlem tamamlanır, ardından en son
//   pendingText ile yeni yazma başlatılır. Böylece:
//     - Hızlı ardışık kaydetmelerde veri kaybı yaşanmaz.
//     - Atomik mv yarıda kesilmez.
Item {
    id: root

    visible: false
    width: 0
    height: 0

    property string path: ""
    property string readBuffer: ""
    property string pendingText: ""
    // Mevcut yazma biterken yeni bir write() gelirse true yapılır.
    property bool _writeQueued: false

    signal loaded(string text)
    signal saved(string text)
    signal failed(string phase, int exitCode, string details)

    // Tek tırnak içindeki tek tırnakları güvenli şekilde escape eder.
    function shellQuote(text) {
        return "'" + String(text).replace(/'/g, "'\\''") + "'";
    }

    function read() {
        if (root.path.length === 0 || readProc.running) return;
        root.readBuffer = "";
        readProc.running = true;
    }

    function write(text) {
        if (root.path.length === 0) return;
        root.pendingText = text;
        if (writeProc.running) {
            // Mevcut yazma bitmeden yenisini başlatma; tamamlanınca
            // en güncel pendingText ile devam edilecek.
            root._writeQueued = true;
        } else {
            writeProc.running = true;
        }
    }

    // ------------------------------------------------------------------
    // Okuma process'i
    // ------------------------------------------------------------------
    Process {
        id: readProc
        command: root.path.length > 0
            ? ["sh", "-c", "cat " + root.shellQuote(root.path) + " 2>/dev/null || true"]
            : []
        running: false
        stdout: SplitParser { onRead: data => { root.readBuffer += data; } }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.failed("read", exitCode, "");
            }
            root.loaded(root.readBuffer);
            root.readBuffer = "";
        }
    }

    // ------------------------------------------------------------------
    // Yazma process'i — atomik geçici dosya + mv
    // ------------------------------------------------------------------
    Process {
        id: writeProc
        command: root.path.length > 0 ? [
            "sh", "-c",
            // 1. Hedef dizini oluştur
            // 2. Geçici dosya aç (aynı dizinde, mv atomik olsun)
            // 3. İçeriği geçiciğye yaz
            // 4. Hedefe taşı (atomik)
            // 5. Herhangi bir adım başarısız olursa geçiciyi temizle
            "d=$(dirname " + root.shellQuote(root.path) + ") && " +
            "mkdir -p \"$d\" && " +
            "tmp=$(mktemp \"$d/.XXXXXX\") && " +
            "{ printf '%s' " + root.shellQuote(root.pendingText) + " > \"$tmp\" && " +
            "mv -- \"$tmp\" " + root.shellQuote(root.path) + "; } || { rm -f \"$tmp\"; exit 1; }"
        ] : []
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                root.saved(root.pendingText);
            } else {
                root.failed("write", exitCode, "");
            }
            // Kuyrukta bekleyen yazma varsa en güncel içerikle başlat.
            if (root._writeQueued) {
                root._writeQueued = false;
                writeProc.running = true;
            }
        }
    }
}
