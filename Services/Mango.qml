pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "./core/Log.js" as Log

Singleton {
    id: root

    // Per-monitor workspace data: { "DP-2": [{tagNum, state, clients, focused}], "DP-3": [...] }
    property var monitorWorkspaces: ({})

    function applyTagPayload(payload) {
        var entries = payload && Array.isArray(payload.all_tags) ? payload.all_tags : [];
        var monData = {};
        for (var mi = 0; mi < entries.length; ++mi) {
            var entry = entries[mi] || {};
            var monitorName = String(entry.monitor || "");
            if (monitorName === "") continue;
            var tags = Array.isArray(entry.tags) ? entry.tags : [];
            monData[monitorName] = [];
            for (var ti = 0; ti < tags.length; ++ti) {
                var tag = tags[ti] || {};
                monData[monitorName].push({
                    tagNum: Number(tag.index) || 0,
                    state: tag.is_urgent === true ? 2 : (tag.is_active === true ? 1 : 0),
                    clients: Number(tag.client_count) || 0,
                    focused: 0
                });
            }
        }
        root.monitorWorkspaces = monData;
    }

    // Mango 0.16+ JSON tag event stream.
    Process {
        id: mangoEvents
        running: CompositorService.isMango
        command: ["mmsg", "watch", "all-tags"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.applyTagPayload(JSON.parse(String(data || "").trim()));
                } catch (e) {
                    Log.warn("Mango", "Tag event parse error: " + e);
                }
            }
        }
    }

    Process {
        id: refreshTagsProc
        command: ["mmsg", "get", "all-tags"]
        property string buf: ""

        stdout: SplitParser {
            onRead: data => { refreshTagsProc.buf += data; }
        }

        onExited: {
            try {
                root.applyTagPayload(JSON.parse(refreshTagsProc.buf || "{}"));
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
