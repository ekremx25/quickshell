import QtQuick
import Quickshell.Io
import "../../../Widgets"
import "../../../Services/core" as Core

Item {
    id: service
    visible: false
    width: 0
    height: 0

    property string currentProfile: "balanced"
    property bool available: false
    property var availableProfiles: []

    readonly property string helperPath: Core.PathService.configPath("scripts/power-profile.py")

    readonly property var profileData: ({
        "performance": { icon: "󰓅", label: "Performance", color: Theme.cpRed },
        "balanced":    { icon: "󰾅", label: "Balanced", color: Theme.powerProfileColor },
        "power-saver": { icon: "󰾆", label: "Power Saver", color: Theme.cpGreen }
    })

    function refresh() {
        if (getProc.running) return;
        getProc.output = "";
        getProc.running = true;
    }

    function setProfile(profile) {
        if (!profile || setProc.running || availableProfiles.indexOf(profile) === -1) return;
        setProc.command = ["python3", helperPath, "set", profile];
        setProc.running = true;
    }

    Process {
        id: getProc
        command: ["python3", service.helperPath, "status"]
        property string output: ""
        stdout: SplitParser { onRead: data => getProc.output += data }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                service.available = false;
                getProc.output = "";
                return;
            }

            try {
                var status = JSON.parse(getProc.output.trim());
                var profile = status.active || "";
                var profiles = status.profiles || [];
                if (profiles.indexOf(profile) === -1)
                    profiles.push(profile);

                if (profile !== "performance" && profile !== "balanced" && profile !== "power-saver")
                    throw new Error("Invalid active power profile");

                service.currentProfile = profile;
                service.availableProfiles = profiles;
                service.available = true;
            } catch (error) {
                service.available = false;
                service.availableProfiles = [];
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
