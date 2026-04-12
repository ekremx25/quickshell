import QtQuick
import Quickshell.Io
import "../../../Widgets"

Item {
    id: service
    visible: false
    width: 0
    height: 0

    property string currentProfile: "balanced"
    property bool available: true

    readonly property var profileData: ({
        "performance": { icon: "󰓅", label: "Performance", color: "#f38ba8" },
        "balanced":    { icon: "󰾅", label: "Balanced", color: Theme.powerProfileColor },
        "power-saver": { icon: "󰾆", label: "Power Saver", color: "#a6e3a1" }
    })

    function refresh() {
        if (getProc.running) return;
        getProc.output = "";
        getProc.running = true;
    }

    function setProfile(profile) {
        if (!profile || setProc.running) return;
        setProc.command = ["powerprofilesctl", "set", profile];
        setProc.running = true;
    }

    Process {
        id: getProc
        command: ["powerprofilesctl", "get"]
        property string output: ""
        stdout: SplitParser { onRead: data => getProc.output += data }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                service.available = false;
                getProc.output = "";
                return;
            }

            var profile = getProc.output.trim();
            if (profile === "performance" || profile === "balanced" || profile === "power-saver") {
                service.currentProfile = profile;
                service.available = true;
            } else {
                service.available = false;
            }
            getProc.output = "";
        }
    }

    Process {
        id: setProc
        command: []
        onExited: service.refresh()
    }

    Component.onCompleted: service.refresh()

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: service.refresh()
    }
}
