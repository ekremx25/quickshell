import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: backend

    visible: false
    width: 0
    height: 0

    property bool installed: false
    property bool daemonEnabled: false
    property bool daemonActive: false
    property bool managed: false
    property bool busy: false
    property string version: ""
    property string activeProfile: "Custom layout"
    property string message: ""
    property string errorMessage: ""
    property var monitors: []
    property var profiles: []

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string actionScript: homeDir + "/.config/quickshell/scripts/hyprmoncfg_action.sh"

    function cleanProfileName(value) {
        var cleaned = String(value || "").trim().replace(/[^A-Za-z0-9._-]+/g, "-");
        return cleaned.replace(/^-+|-+$/g, "").slice(0, 48);
    }

    function refresh() {
        if (!versionProcess.running) versionProcess.running = true;
        if (!statusProcess.running) statusProcess.running = true;
        if (!monitorProcess.running) monitorProcess.running = true;
        if (!profileProcess.running) profileProcess.running = true;
        if (!enabledProcess.running) enabledProcess.running = true;
        if (!activeProcess.running) activeProcess.running = true;
    }

    function runAction(action, argument) {
        if (busy) return;
        busy = true;
        message = "";
        errorMessage = "";
        var argv = [actionScript, action];
        if (argument !== undefined && String(argument).length > 0) argv.push(String(argument));
        actionProcess.command = argv;
        actionProcess.running = true;
    }

    function saveProfile(name) {
        var safe = cleanProfileName(name);
        if (!safe) {
            errorMessage = "Please enter a profile name.";
            return;
        }
        runAction("save", safe);
    }

    function syncCurrentProfile() {
        var current = cleanProfileName(activeProfile);
        if (!current || current.toLowerCase() === "custom-layout") current = "linuxlifex-dual";
        runAction("save", current);
    }

    function applyProfile(name) {
        if (busy || !name) return;
        message = "Confirm the layout in the opened terminal.";
        errorMessage = "";
        editorProcess.command = ["xdg-terminal-exec", "--app-id=TUI.float", "-e", "hyprmoncfg", "apply", String(name)];
        editorProcess.startDetached();
    }
    function deleteProfile(name) { runAction("delete", name); }
    function enableManagement() { runAction("enable", ""); }
    function disableManagement() { runAction("disable", ""); }

    function openEditor() {
        editorProcess.command = ["gtk-launch", "hyprmoncfg"];
        editorProcess.startDetached();
    }

    Component.onCompleted: refresh()

    Process {
        id: versionProcess
        property string output: ""
        command: ["hyprmoncfg", "version"]
        stdout: SplitParser { onRead: data => versionProcess.output += data + "\n" }
        stderr: SplitParser { onRead: data => versionProcess.output += data + "\n" }
        onRunningChanged: if (running) output = ""
        onExited: code => {
            backend.installed = code === 0;
            var match = output.match(/hyprmoncfg\s+([^\s]+)/);
            backend.version = match ? match[1] : "";
        }
    }

    Process {
        id: statusProcess
        property string output: ""
        command: ["hyprmoncfg", "status"]
        stdout: SplitParser { onRead: data => statusProcess.output += data + "\n" }
        stderr: SplitParser { onRead: data => statusProcess.output += data + "\n" }
        onRunningChanged: if (running) output = ""
        onExited: code => {
            if (code !== 0) return;
            var profile = output.match(/Active profile:\s*(.+)/i);
            var daemon = output.match(/Daemon:\s*(.+)/i);
            backend.activeProfile = profile ? profile[1].trim() : "Custom layout";
            if (daemon) backend.daemonActive = daemon[1].toLowerCase().indexOf("running") >= 0;
            backend.managed = backend.daemonActive || backend.activeProfile.toLowerCase().indexOf("not managed") < 0;
        }
    }

    Process {
        id: monitorProcess
        property string output: ""
        command: ["hyprctl", "monitors", "-j"]
        stdout: SplitParser { splitMarker: ""; onRead: data => monitorProcess.output += data }
        stderr: SplitParser { onRead: data => {} }
        onRunningChanged: if (running) output = ""
        onExited: code => {
            if (code !== 0) return;
            try {
                var parsed = JSON.parse(output);
                backend.monitors = parsed.map(function(item) {
                    return {
                        name: String(item.name || "Display"),
                        description: String(item.description || item.model || "Monitor"),
                        width: Number(item.width || 0),
                        height: Number(item.height || 0),
                        refreshRate: Number(item.refreshRate || 0),
                        scale: Number(item.scale || 1),
                        x: Number(item.x || 0),
                        y: Number(item.y || 0),
                        focused: !!item.focused,
                        vrr: !!item.vrr
                    };
                });
            } catch (error) {
                backend.errorMessage = "Could not read the current monitor layout.";
            }
        }
    }

    Process {
        id: profileProcess
        property string output: ""
        command: ["sh", "-lc", "for f in \"$HOME\"/.config/hyprmoncfg/profiles/*.json; do test -e \"$f\" || continue; basename \"$f\" .json; done"]
        stdout: SplitParser { onRead: data => profileProcess.output += data + "\n" }
        onRunningChanged: if (running) output = ""
        onExited: {
            var names = output.split(/\r?\n/).map(function(value) { return value.trim(); })
                .filter(function(value) { return value.length > 0; });
            names.sort();
            backend.profiles = names;
        }
    }

    Process {
        id: enabledProcess
        command: ["systemctl", "--user", "is-enabled", "--quiet", "hyprmoncfgd.service"]
        onExited: code => backend.daemonEnabled = code === 0
    }

    Process {
        id: activeProcess
        command: ["systemctl", "--user", "is-active", "--quiet", "hyprmoncfgd.service"]
        onExited: code => backend.daemonActive = code === 0
    }

    Process {
        id: actionProcess
        property string output: ""
        stdout: SplitParser { onRead: data => actionProcess.output += data + "\n" }
        stderr: SplitParser { onRead: data => actionProcess.output += data + "\n" }
        onRunningChanged: if (running) output = ""
        onExited: code => {
            backend.busy = false;
            var result = output.trim();
            if (code === 0) backend.message = result || "Done.";
            else backend.errorMessage = result || "The operation could not be completed.";
            refreshDelay.restart();
        }
    }

    Process { id: editorProcess }

    Timer {
        id: refreshDelay
        interval: 500
        repeat: false
        onTriggered: backend.refresh()
    }
}
