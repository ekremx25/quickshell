import QtQuick
import Quickshell
import Quickshell.Io

// Top-level VPN popup manager — independent of Settings PanelWindow
// Watches for /tmp/qs_vpn_open trigger file to open the popup
Item {
    id: vpnManager

    // File watcher: check for trigger file every 300ms
    Timer {
        id: triggerWatcher
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            triggerCheckProc.running = false;
            triggerCheckProc.running = true;
        }
    }

    // Check if trigger file exists
    Process {
        id: triggerCheckProc
        command: ["sh", "-c", "test -f /tmp/qs_vpn_open && echo 'yes' && rm /tmp/qs_vpn_open || echo 'no'"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { triggerCheckProc.buf = data.trim(); } }
        onExited: {
            if (triggerCheckProc.buf === "yes") {
                console.log("VpnManager: trigger detected, opening popup");
                addVpnPopup.open();
            }
            triggerCheckProc.buf = "";
        }
    }

    AddVpnPopup {
        id: addVpnPopup
        onSuccess: {
            console.log("VpnManager: VPN added successfully");
            // Trigger NetworkPage refresh via file
            refreshTriggerProc.running = true;
        }
    }

    Process {
        id: refreshTriggerProc
        command: ["touch", "/tmp/qs_vpn_refresh"]
    }
}
