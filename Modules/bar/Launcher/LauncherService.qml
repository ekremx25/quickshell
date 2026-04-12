import QtQuick
import Quickshell.Io

Item {
    id: service

    visible: false
    width: 0
    height: 0

    property string distroName: ""

    readonly property var distroIconMap: ({
        "gentoo": "\ue7e6",
        "fedora": "\ue7d9",
        "ubuntu": "\uef72",
        "debian": "\ue77d",
        "arch": "\uf31e",
        "nixos": "\ue843",
        "opensuse": "\uf314",
        "linux mint": "\uf30e",
        "elementary": "\uf309"
    })

    function distroIcon(name) {
        var lowered = String(name || "").toLowerCase();
        var keys = Object.keys(distroIconMap);
        for (var i = 0; i < keys.length; i++) {
            if (lowered.indexOf(keys[i]) !== -1) return distroIconMap[keys[i]];
        }
        return "\ue712";
    }

    Process {
        id: distroProc
        command: ["sh", "-c", "grep '^PRETTY_NAME=' /etc/os-release | cut -d'\"' -f2"]
        property string buf: ""
        stdout: SplitParser { onRead: data => { distroProc.buf = data.trim(); } }
        running: true
        onExited: {
            service.distroName = distroProc.buf;
            distroProc.buf = "";
        }
    }
}
