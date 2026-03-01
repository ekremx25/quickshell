pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

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
            console.log("[CompositorService] Compositor:", compositor);
            applySavedMonitorsProc.running = true;
            refreshMonitors();
        }
    }

    // Mango detection via mmsg
    Process {
        id: mangoDetectProc
        command: ["sh", "-c", "command -v mmsg && echo yes || echo no"]
        property string buf: ""
        stdout: SplitParser { onRead: data => { mangoDetectProc.buf += data; } }
        onExited: {
            root.mangoDetected = mangoDetectProc.buf.trim().indexOf("yes") !== -1;
            console.log("[CompositorService] Compositor:", root.compositor);
            applySavedMonitorsProc.running = true;
            root.refreshMonitors();
            mangoDetectProc.buf = "";
        }
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
        } else if (isMango) {
            mangoMonitorProc.buf = "";
            mangoMonitorProc.running = true;
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
                    // mmsg -O çıktısını parse et - her satır bir monitor
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
                console.log("[CompositorService] Mango Monitor parse error: " + e);
            }
            mangoMonitorProc.buf = "";
        }
    }

    // Power controls
    function powerOnMonitors() {
        if (isHyprland) {
            hyprPowerOnProc.running = true;
        } else if (isNiri) {
            powerOnProc.running = true;
        } else if (isMango) {
            mangoPowerOnProc.running = true;
        }
    }

    function powerOffMonitors() {
        if (isHyprland) {
            hyprPowerOffProc.running = true;
        } else if (isNiri) {
            powerOffProc.running = true;
        } else if (isMango) {
            mangoPowerOffProc.running = true;
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
            focusProc.running = true;
        } else if (isNiri) {
            focusProc.command = ["sh", "-c", "niri msg --json windows | jq -r '.[] | select(.app_id==\"" + appId + "\") | .id' | head -1 | xargs -I{} niri msg action focus-window --id {}"];
            focusProc.running = true;
        } else if (isMango) {
            // Mango'da direkt pencere odaklama sınırlı, focusstack ile dene
            console.log("[CompositorService] Mango focusWindow not fully supported for appId: " + appId);
        }
    }

    Process { id: focusProc; command: [] }

    // Info string
    function getInfoString() {
        if (isHyprland) return "Hyprland (Wayland) — " + hyprlandSignature;
        if (isNiri) return "Niri (Wayland) — " + niriSocket;
        if (isMango) return "MangoWC (Wayland)";
        return "Unknown (Wayland)";
    }
}
