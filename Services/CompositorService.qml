pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Niri-only compositor
    // Compositor detection
    readonly property string niriSocket: Quickshell.env("NIRI_SOCKET") || ""
    readonly property string hyprlandSignature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""

    property bool isNiri: niriSocket !== ""
    property bool isHyprland: hyprlandSignature !== ""
    property string compositor: isHyprland ? "hyprland" : (isNiri ? "niri" : "unknown")

    // Monitor info
    property var monitors: []

    Component.onCompleted: {
        console.log("[CompositorService] Compositor:", compositor);
        // Apply saved monitors from monitor_config.json 
        applySavedMonitorsProc.running = true;
        refreshMonitors();
    }
    
    Process {
        id: applySavedMonitorsProc
        command: ["sh", "-c", "$HOME/.config/quickshell/scripts/apply_monitors.sh"]
    }

    // Monitor listing via niri msg
    // Monitor listing via hyprctl or niri msg
    function refreshMonitors() {
        if (isHyprland) {
            hyprlandMonitorProc.buf = "";
            hyprlandMonitorProc.running = true;
        } else if (isNiri) {
            niriMonitorProc.buf = "";
            niriMonitorProc.running = true;
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
                console.log("[CompositorService] Hyprland Monitor parse error: " + e);
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
                console.log("[CompositorService] Monitor parse error: " + e);
            }
            niriMonitorProc.buf = "";
        }
    }

    // Power controls
    function powerOnMonitors() {
        if (isHyprland) {
            hyprPowerOnProc.running = true;
        } else if (isNiri) {
            powerOnProc.running = true;
        }
    }

    function powerOffMonitors() {
        if (isHyprland) {
            hyprPowerOffProc.running = true;
        } else if (isNiri) {
            powerOffProc.running = true;
        }
    }

    Process { id: powerOnProc; command: ["niri", "msg", "action", "power-on-monitors"] }
    Process { id: powerOffProc; command: ["niri", "msg", "action", "power-off-monitors"] }
    Process { id: hyprPowerOnProc; command: ["hyprctl", "dispatch", "dpms", "on"] }
    Process { id: hyprPowerOffProc; command: ["hyprctl", "dispatch", "dpms", "off"] }

    // Focus a window by app-id
    function focusWindow(appId) {
        if (isHyprland) {
            focusProc.command = ["hyprctl", "dispatch", "focuswindow", "class:" + appId];
            focusProc.running = true;
        } else if (isNiri) {
            focusProc.command = ["sh", "-c", "niri msg --json windows | jq -r '.[] | select(.app_id==\"" + appId + "\") | .id' | head -1 | xargs -I{} niri msg action focus-window --id {}"];
            focusProc.running = true;
        }
    }

    Process { id: focusProc; command: [] }

    // Info string
    function getInfoString() {
        if (isHyprland) return "Hyprland (Wayland) — " + hyprlandSignature;
        if (isNiri) return "Niri (Wayland) — " + niriSocket;
        return "Unknown (Wayland)";
    }
}
