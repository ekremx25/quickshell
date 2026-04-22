pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./core/Log.js" as Log

Singleton {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")
    readonly property string configDir: configHome + "/quickshell"
    readonly property string monitorScriptPath: configDir + "/scripts/apply_monitors.sh"

    // Compositor detection
    readonly property string niriSocket: Quickshell.env("NIRI_SOCKET") || ""
    readonly property string hyprlandSignature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""

    property bool isNiri: niriSocket !== ""
    property bool isHyprland: hyprlandSignature !== ""
    property bool isMango: !isHyprland && !isNiri && mangoDetected
    property bool mangoDetected: false
    property string compositor: isHyprland ? "hyprland" : (isNiri ? "niri" : (isMango ? "mango" : "unknown"))

    // Monitor info
    property var monitors: []

    Component.onCompleted: {
        // Detect Mango if not Hyprland or Niri
        if (!isHyprland && !isNiri) {
            mangoDetectProc.running = true;
        } else {
            applySavedMonitorsProc.running = true;
            refreshMonitors();
        }
    }

    function startProcess(proc, clearBuffer) {
        if (proc.running) return;
        if (clearBuffer && proc.buf !== undefined) proc.buf = "";
        proc.running = true;
    }

    // Mango detection via mmsg
    Process {
        id: mangoDetectProc
        command: ["sh", "-c", "command -v mmsg && echo yes || echo no"]
        property string buf: ""
        stdout: SplitParser { onRead: data => { mangoDetectProc.buf += data; } }
        onExited: {
            root.mangoDetected = mangoDetectProc.buf.trim().indexOf("yes") !== -1;
            applySavedMonitorsProc.running = true;
            root.refreshMonitors();
            mangoDetectProc.buf = "";
        }
    }
    
    Process {
        id: applySavedMonitorsProc
        command: [root.monitorScriptPath]
    }

    // Monitor listing via niri msg
    // Monitor listing via hyprctl or niri msg
    function refreshMonitors() {
        if (isHyprland) {
            startProcess(hyprlandMonitorProc, true);
        } else if (isNiri) {
            startProcess(niriMonitorProc, true);
        } else if (isMango) {
            startProcess(mangoMonitorProc, true);
        }
    }

    Process {
        id: hyprlandMonitorProc
        command: ["hyprctl", "monitors", "-j"]
        property string buf: ""
        stdout: SplitParser { onRead: data => { hyprlandMonitorProc.buf += data; } }
        onExited: {
            try {
                var outputs = JSON.parse(hyprlandMonitorProc.buf);
                var list = [];
                for (var i = 0; i < outputs.length; i++) {
                    var o = outputs[i];
                    list.push({
                        name: o.name || "",
                        make: o.make || "",
                        model: o.model || "",
                        width: o.width || 0,
                        height: o.height || 0,
                        refreshRate: o.refreshRate ? o.refreshRate.toFixed(1) : "0",
                        scale: o.scale || 1.0
                    });
                }
                root.monitors = list;
            } catch(e) {
                Log.warn("CompositorService", "Hyprland monitor parse error: " + e);
            }
            hyprlandMonitorProc.buf = "";
        }
    }

    Process {
        id: niriMonitorProc
        command: ["niri", "msg", "--json", "outputs"]
        property string buf: ""
        stdout: SplitParser { onRead: data => { niriMonitorProc.buf += data; } }
        onExited: {
            try {
                var outputs = JSON.parse(niriMonitorProc.buf);
                var list = [];
                for (var name in outputs) {
                    var o = outputs[name];
                    list.push({
                        name: name,
                        make: o.make || "",
                        model: o.model || "",
                        width: o.currentMode ? o.currentMode.width : 0,
                        height: o.currentMode ? o.currentMode.height : 0,
                        refreshRate: o.currentMode ? (o.currentMode.refreshRate / 1000.0).toFixed(1) : "0",
                        scale: o.scale || 1.0
                    });
                }
                root.monitors = list;
            } catch(e) {
                Log.warn("CompositorService", "Niri monitor parse error: " + e);
            }
            niriMonitorProc.buf = "";
        }
    }

    // Mango monitor listing via mmsg -O
    Process {
        id: mangoMonitorProc
        command: ["mmsg", "-O"]
        property string buf: ""
        stdout: SplitParser { onRead: data => { mangoMonitorProc.buf += data; } }
        onExited: {
            try {
                var lines = mangoMonitorProc.buf.trim().split("\n");
                var list = [];
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line === "") continue;
                    // Parse mmsg -O output — each line is one monitor
                    list.push({
                        name: line,
                        make: "",
                        model: "",
                        width: 0,
                        height: 0,
                        refreshRate: "0",
                        scale: 1.0
                    });
                }
                if (list.length > 0) root.monitors = list;
            } catch(e) {
                Log.warn("CompositorService", "Mango monitor parse error: " + e);
            }
            mangoMonitorProc.buf = "";
        }
    }

    // Power controls
    function powerOnMonitors() {
        if (isHyprland) {
            startProcess(hyprPowerOnProc, false);
        } else if (isNiri) {
            startProcess(powerOnProc, false);
        } else if (isMango) {
            startProcess(mangoPowerOnProc, false);
        }
    }

    function powerOffMonitors() {
        if (isHyprland) {
            startProcess(hyprPowerOffProc, false);
        } else if (isNiri) {
            startProcess(powerOffProc, false);
        } else if (isMango) {
            startProcess(mangoPowerOffProc, false);
        }
    }

    Process { id: powerOnProc; command: ["niri", "msg", "action", "power-on-monitors"] }
    Process { id: powerOffProc; command: ["niri", "msg", "action", "power-off-monitors"] }
    Process { id: hyprPowerOnProc; command: ["hyprctl", "dispatch", "dpms", "on"] }
    Process { id: hyprPowerOffProc; command: ["hyprctl", "dispatch", "dpms", "off"] }
    Process { id: mangoPowerOnProc; command: ["sh", "-c", "wlr-randr --output '*' --on 2>/dev/null || true"] }
    Process { id: mangoPowerOffProc; command: ["sh", "-c", "wlr-randr --output '*' --off 2>/dev/null || true"] }

    // Focus a window by app-id
    function focusWindow(appId) {
        if (isHyprland) {
            focusProc.command = ["hyprctl", "dispatch", "focuswindow", "class:" + appId];
            startProcess(focusProc, false);
        } else if (isNiri) {
            focusProc.command = [
                "sh",
                "-c",
                "niri msg --json windows | jq -r --arg appId \"$1\" '.[] | select(.app_id == $appId) | .id' | head -1 | xargs -r -I{} niri msg action focus-window --id {}",
                "sh",
                appId
            ];
            startProcess(focusProc, false);
        } else if (isMango) {
            Log.warn("CompositorService", "Mango focusWindow not supported for appId: " + appId);
        }
    }

    Process { id: focusProc; command: [] }

    Process {
        id: focusByNameProc
        command: []
        running: false
    }

    function focusAppByName(appName) {
        if (!appName || appName.trim() === "") return;
        var needle = appName.toLowerCase();
        if (isHyprland) {
            focusByNameProc.command = [
                "sh",
                "-c",
                "hyprctl clients -j | jq -r --arg needle \"$1\" '.[] | select((((.class // \"\") | ascii_downcase) | contains($needle)) or (((.title // \"\") | ascii_downcase) | contains($needle))) | .address' | head -1 | xargs -r -I{} hyprctl dispatch focuswindow address:{}",
                "sh",
                needle
            ];
            startProcess(focusByNameProc, false);
        } else if (isNiri) {
            focusByNameProc.command = [
                "sh",
                "-c",
                "niri msg --json windows | jq -r --arg needle \"$1\" '.[] | select((((.app_id // \"\") | ascii_downcase) | contains($needle)) or (((.title // \"\") | ascii_downcase) | contains($needle))) | .id' | head -1 | xargs -r -I{} niri msg action focus-window --id {}",
                "sh",
                needle
            ];
            startProcess(focusByNameProc, false);
        } else if (isMango) {
            Log.warn("CompositorService", "Mango focusAppByName not supported for: " + appName);
        }
    }

    // Info string
    function getInfoString() {
        if (isHyprland) return "Hyprland (Wayland) — " + hyprlandSignature;
        if (isNiri) return "Niri (Wayland) — " + niriSocket;
        if (isMango) return "MangoWC (Wayland)";
        return "Unknown (Wayland)";
    }
}
