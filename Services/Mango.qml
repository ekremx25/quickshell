pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "./core/Log.js" as Log

Singleton {
    id: root

    // Per-monitor workspace data: { "DP-2": [{tagNum, state, clients, focused}], "DP-3": [...] }
    property var monitorWorkspaces: ({})

    // mmsg -w -t event stream: watch for tag changes
    Process {
        id: mangoEvents
        running: CompositorService.isMango
        command: ["mmsg", "-w", "-t"]

        stdout: SplitParser {
            onRead: data => {
                // Each event triggers a fresh tag read.
                refreshTagsProc.running = true;
            }
        }
    }

    // Parse mmsg -g -t output.
    // Output format (from mmsg.c):
    //   DP-2 tag 1 1 2 1     ← monitor tag_num state clients focused
    //   DP-2 tag 2 0 0 0
    //   ...
    //   DP-2 clients 5       ← total clients
    //   DP-2 tags 7 2 0      ← occ sel urg bitmask
    //   DP-2 tags 000000111 000000010 000000000  ← 9-bit binary
    //   DP-3 tag 1 1 1 0     ← second monitor
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

                    // "DP-2 tag 1 1 2 1" format
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
                    // Skip "clients" and "tags" lines — per-tag info is enough.
                }

                root.monitorWorkspaces = monData;
            } catch (e) {
                Log.warn("Mango", "Tag parse error: " + e);
            }
            refreshTagsProc.buf = "";
        }
    }

    // Fetch tag data on first start.
    Component.onCompleted: {
        if (CompositorService.isMango) {
            refreshTagsProc.running = true;
        }
    }

    // Returns the workspace list for a given monitor.
    function getWorkspacesForMonitor(monitorName) {
        var data = root.monitorWorkspaces[monitorName];
        if (!data) return [];
        return data;
    }
}
