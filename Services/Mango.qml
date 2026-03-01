pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Monitor bazlı workspace verileri: { "DP-2": [{tagNum, state, clients, focused}], "DP-3": [...] }
    property var monitorWorkspaces: ({})

    // mmsg -w -t event stream: tag değişikliklerini izle
    Process {
        id: mangoEvents
        running: CompositorService.isMango
        command: ["mmsg", "-w", "-t"]

        stdout: SplitParser {
            onRead: data => {
                // Her event geldiğinde tag bilgilerini yeniden oku
                refreshTagsProc.running = true;
            }
        }
    }

    // mmsg -g -t çıktısını parse et
    // Çıktı formatı (mmsg.c kaynak kodundan):
    //   DP-2 tag 1 1 2 1     ← monitor tag_num state clients focused
    //   DP-2 tag 2 0 0 0
    //   ...
    //   DP-2 clients 5       ← toplam client
    //   DP-2 tags 7 2 0      ← occ sel urg bitmask
    //   DP-2 tags 000000111 000000010 000000000  ← 9-bit binary
    //   DP-3 tag 1 1 1 0     ← ikinci monitör
    //   ...
    Process {
        id: refreshTagsProc
        command: ["mmsg", "-g", "-t"]
        property string buf: ""

        stdout: SplitParser {
            onRead: data => { refreshTagsProc.buf += data; }
        }

        onExited: {
            try {
                var lines = refreshTagsProc.buf.trim().split("\n");
                var monData = {};

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line === "") continue;

                    var parts = line.split(/\s+/);
                    if (parts.length < 2) continue;

                    var monName = parts[0];

                    // "DP-2 tag 1 1 2 1" formatı
                    if (parts[1] === "tag" && parts.length >= 6) {
                        var tagNum = parseInt(parts[2]);
                        var state = parseInt(parts[3]);
                        var clients = parseInt(parts[4]);
                        var focused = parseInt(parts[5]);

                        if (isNaN(tagNum)) continue;

                        if (!monData[monName]) monData[monName] = [];

                        monData[monName].push({
                            tagNum: tagNum,
                            state: state,       // 0=none, 1=active, 2=urgent
                            clients: clients,
                            focused: focused
                        });
                    }
                    // "clients" ve "tags" satırlarını atlayabiliriz, per-tag bilgi yeterli
                }

                root.monitorWorkspaces = monData;
            } catch (e) {
                console.log("[Mango] Tag Parse Error:", e);
            }
            refreshTagsProc.buf = "";
        }
    }

    // İlk başlatmada tag bilgilerini al
    Component.onCompleted: {
        if (CompositorService.isMango) {
            refreshTagsProc.running = true;
        }
    }

    // Belirli bir monitör için workspace listesini döndür
    function getWorkspacesForMonitor(monitorName) {
        var data = root.monitorWorkspaces[monitorName];
        if (!data) return [];
        return data;
    }
}
