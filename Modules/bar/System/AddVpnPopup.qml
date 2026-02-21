import QtQuick
import Qt.labs.platform
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../Widgets"

PanelWindow {
    id: root
    
    // Make window cover the whole screen
    anchors { top: true; bottom: true; left: true; right: true }
    
    color: "transparent"
    
    // Use Overlay to ensure it appears above Settings (which is Top)
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    visible: false
    
    signal success
    
    property string importedFilePath: ""
    property string vpnStatus: ""
    property int selectedVpnTypeIndex: 0
    property bool manualFormVisible: importedFilePath === "" && selectedVpnTypeIndex === 0
    
    function open() { visible = true; importedFilePath = ""; vpnStatus = ""; selectedVpnTypeIndex = 0; }
    function close() { visible = false; root.closed(); }

    // Dimmer (Darken background)
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        
        // Close on click outside
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // The Actual Popup Content
    Rectangle {
        width: 600
        height: 620
        anchors.centerIn: parent
        color: "#1e1e2e"
        radius: 16
        border.color: Qt.rgba(255,255,255,0.1)
        border.width: 1

        MouseArea { anchors.fill: parent } // Block click-through to dimmer

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 24
            spacing: 16

            // Header
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 4
                    Text { text: "Add VPN Connection"; color: Theme.text; font.bold: true; font.pixelSize: 16 }
                    Text { text: "Configure a new VPN connection"; color: Theme.subtext; font.pixelSize: 12 }
                }
                Item { Layout.fillWidth: true }
                Text { text: "✕"; color: Theme.subtext; font.pixelSize: 16; MouseArea { anchors.fill: parent; onClicked: root.close(); cursorShape: Qt.PointingHandCursor } }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.1) }

            // Type Selector
            ColumnLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: "VPN Type"; color: Theme.subtext; font.pixelSize: 12 }
                Flow {
                    Layout.fillWidth: true; spacing: 8
                    Repeater {
                        model: ["OpenVPN", "WireGuard", "IKEv2", "L2TP", "PPTP"]
                        Rectangle {
                            width: typeText.implicitWidth + 24; height: 30; radius: 15
                            color: root.selectedVpnTypeIndex === index ? Theme.primary : Qt.rgba(255,255,255,0.05)
                            
                            Text { 
                                id: typeText
                                anchors.centerIn: parent
                                text: modelData
                                color: root.selectedVpnTypeIndex === index ? "#1e1e2e" : Theme.text
                                font.pixelSize: 12 
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedVpnTypeIndex = index
                            }
                        }
                    }
                }
            }

            // Import Button / Path Display
            ColumnLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; height: 40; radius: 8
                    color: Qt.rgba(137/255, 180/255, 250/255, 0.15)
                    border.color: "#89b4fa"; border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 12
                        Text { 
                            text: root.importedFilePath ? "📄 " + root.importedFilePath.split("/").pop() : (root.selectedVpnTypeIndex === 1 ? "Import .conf File" : "Import .ovpn File")
                            color: "#89b4fa"; font.bold: true; Layout.fillWidth: true; elide: Text.ElideMiddle
                        }
                        Text { text: "Browse"; color: "#89b4fa"; visible: !root.importedFilePath }
                        Text { text: "Clear"; color: "#f38ba8"; visible: root.importedFilePath !== ""; MouseArea { anchors.fill: parent; onClicked: root.importedFilePath = "" } }
                    }
                    
                    MouseArea { 
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor 
                        enabled: root.importedFilePath === ""
                        onClicked: root.openFileDialog()
                    }
                }
                Text { visible: root.importedFilePath !== ""; text: "Using imported file configuration directly."; color: Theme.subtext; font.italic: true; font.pixelSize: 11 }
            }

            // Manual Config Form (OpenVPN Only)
            ColumnLayout {
                visible: root.manualFormVisible
                Layout.fillWidth: true; spacing: 12
                opacity: visible ? 1 : 0.5
                
                Text { text: "Manual Configuration"; color: Theme.subtext; font.pixelSize: 12 }
                
                // Connection Name
                Rectangle {
                    Layout.fillWidth: true; height: 40; radius: 8
                    color: Qt.rgba(0,0,0,0.3); border.color: vpnNameInput.activeFocus ? Theme.primary : Qt.rgba(255,255,255,0.1); border.width: 1
                    TextInput { id: vpnNameInput; anchors.fill: parent; anchors.margins: 10; color: Theme.text; text: "My OpenVPN"; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true }
                }

                // Server & Port
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Rectangle {
                        Layout.fillWidth: true; height: 40; radius: 8
                        color: Qt.rgba(0,0,0,0.3); border.color: vpnServerInput.activeFocus ? Theme.primary : Qt.rgba(255,255,255,0.1); border.width: 1
                        TextInput { id: vpnServerInput; anchors.fill: parent; anchors.margins: 10; color: Theme.text; text: ""; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true 
                            Text { text: "Server Address"; visible: parent.text === "" && !parent.activeFocus; color: Theme.overlay; anchors.verticalCenter: parent.verticalCenter; leftPadding: 10 }
                        }
                    }
                    Rectangle {
                        width: 80; height: 40; radius: 8
                        color: Qt.rgba(0,0,0,0.3); border.color: vpnPortInput.activeFocus ? Theme.primary : Qt.rgba(255,255,255,0.1); border.width: 1
                        TextInput { id: vpnPortInput; anchors.fill: parent; anchors.margins: 10; color: Theme.text; text: "1194"; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true }
                    }
                }

                // Username
                Rectangle {
                    Layout.fillWidth: true; height: 40; radius: 8
                    color: Qt.rgba(0,0,0,0.3); border.color: vpnUserInput.activeFocus ? Theme.primary : Qt.rgba(255,255,255,0.1); border.width: 1
                    TextInput { id: vpnUserInput; anchors.fill: parent; anchors.margins: 10; color: Theme.text; text: ""; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true 
                        Text { text: "Username (Optional)"; visible: parent.text === "" && !parent.activeFocus; color: Theme.overlay; anchors.verticalCenter: parent.verticalCenter; leftPadding: 10 }
                    }
                }
                
                // Password
                Rectangle {
                    Layout.fillWidth: true; height: 40; radius: 8
                    color: Qt.rgba(0,0,0,0.3); border.color: vpnPassInput.activeFocus ? Theme.primary : Qt.rgba(255,255,255,0.1); border.width: 1
                    TextInput { id: vpnPassInput; anchors.fill: parent; anchors.margins: 10; color: Theme.text; text: ""; echoMode: TextInput.Password; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true 
                        Text { text: "Password (Optional)"; visible: parent.text === "" && !parent.activeFocus; color: Theme.overlay; anchors.verticalCenter: parent.verticalCenter; leftPadding: 10 }
                    }
                }
            }

            // Hint for other types
            Text {
                visible: root.importedFilePath === "" && root.selectedVpnTypeIndex !== 0
                text: root.selectedVpnTypeIndex === 1 
                      ? "For WireGuard, please import a .conf file."
                      : "Manual configuration for this type is not yet supported."
                color: Theme.subtext; font.italic: true
                Layout.alignment: Qt.AlignHCenter
            }

            Item { Layout.fillHeight: true }
            
            // Status Text
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.vpnStatus
                visible: root.vpnStatus !== ""
                color: text.indexOf("Error") !== -1 ? "#f38ba8" : "#a6e3a1"
                font.bold: true; wrapMode: Text.Wrap
            }

            // Actions
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    width: 80; height: 36; radius: 8
                    color: Qt.rgba(255,255,255,0.1)
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.text }
                    MouseArea { anchors.fill: parent; onClicked: root.close(); cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    width: 80; height: 36; radius: 8
                    color: Theme.primary
                    Text { anchors.centerIn: parent; text: "Add"; color: "#1e1e2e"; font.bold: true }
                    MouseArea { 
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor 
                        onClicked: {
                            if (root.importedFilePath !== "") {
                                // Import mode
                                var type = "openvpn";
                                var filePath = root.importedFilePath;
                                
                                if (root.selectedVpnTypeIndex === 1) {
                                    type = "wireguard";
                                    
                                    // WireGuard interface limitation: filename (minus .conf) must be < 16 chars
                                    // and contain only valid chars. Long filenames cause import failure.
                                    var fileName = filePath.split("/").pop();
                                    if (fileName.length > 15 || fileName.indexOf(" ") !== -1) {
                                        // Create a temporary valid path
                                        var randId = Math.floor(Math.random() * 9000) + 1000;
                                        var newPath = "/tmp/wg_" + randId + ".conf";
                                        
                                        // Handle special chars in path for shell (basic quote escape)
                                        var safeOrig = filePath.replace(/'/g, "'\\''");
                                        
                                        // Copy -> Import -> Remove (cleanup in background or ignore if fails)
                                        // We use sh -c to chain the copy and import
                                        vpnCreationProcess.command = ["sh", "-c", "cp '" + safeOrig + "' " + newPath + " && nmcli connection import type wireguard file " + newPath];
                                        
                                        root.vpnStatus = "Long filename detected. Renaming & importing...";
                                        vpnCreationProcess.running = true;
                                        return;
                                    }
                                }
                                
                                vpnCreationProcess.command = ["nmcli", "connection", "import", "type", type, "file", filePath];
                                root.vpnStatus = "Importing " + type + " profile...";
                                vpnCreationProcess.running = true;
                                return;
                            }

                            // Manual mode (Only OpenVPN implemented)
                            if (root.selectedVpnTypeIndex === 0) {
                                if (vpnServerInput.text === "") {
                                    root.vpnStatus = "Please enter a server address.";
                                    return;
                                }
                                
                                // Basic OpenVPN creation
                                // Construct command for manual entry
                                var cmd = ["nmcli", "connection", "add", "type", "vpn", "vpn-type", "openvpn", "con-name", vpnNameInput.text, "ifname", "*"];
                                
                                var vpnData = [];
                                if (vpnServerInput.text) vpnData.push("remote=" + vpnServerInput.text + ":" + vpnPortInput.text);
                                if (vpnUserInput.text) vpnData.push("username=" + vpnUserInput.text);
                                if (vpnPassInput.text) vpnData.push("password-flags=0"); 
                            
                                if (vpnData.length > 0) {
                                    cmd.push("--", "vpn.data", vpnData.join(","));
                                }
                                
                                vpnCreationProcess.command = cmd;
                                root.vpnStatus = "Adding OpenVPN...";
                                vpnCreationProcess.running = true;
                            } else if (root.selectedVpnTypeIndex === 1) {
                                    root.vpnStatus = "For WireGuard, please import a .conf file.";
                            } else {
                                    root.vpnStatus = "Manual configuration for this type is not yet supported.";
                            }
                        }
                    }
                }
            }
        }
    }

    
    // File Picker Popup
    Rectangle {
        id: filePickerPopup
        anchors.fill: parent
        color: Qt.rgba(0,0,0,0.8)
        z: 1000
        visible: false
        
        MouseArea { anchors.fill: parent } // Block events

        FilePicker {
            id: vpnFilePicker
            anchors.centerIn: parent
            width: 600; height: 500
            extensions: root.selectedVpnTypeIndex === 1 ? ["conf", "txt"] : ["ovpn"]
            title: root.selectedVpnTypeIndex === 1 ? "Select WireGuard Config" : "Select OpenVPN Config"
            
            onFileSelected: (path) => {
                root.importedFilePath = path;
                filePickerPopup.visible = false;
            }
            onCanceled: filePickerPopup.visible = false;
        }
    }
    
    function openFileDialog() {
        filePickerPopup.visible = true;
        vpnFilePicker.currentPath = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", ""); // Reset or persist
        vpnFilePicker.listDir(vpnFilePicker.currentPath);
    }

    // Process for VPN Add/Import
    Process {
        id: vpnCreationProcess
        command: []
        property string errBuf: ""
        stdout: SplitParser { onRead: (data) => console.log("[vpn]: " + data) }
        stderr: SplitParser { onRead: (data) => { vpnCreationProcess.errBuf += data + " "; console.log("[vpn err]: " + data); } }
        onExited: (code) => {
            if (code !== 0) {
                var err = vpnCreationProcess.errBuf;
                if (err.indexOf("unknown VPN plugin") !== -1 || err.indexOf("org.freedesktop.NetworkManager.openvpn") !== -1) {
                        root.vpnStatus = "❌ Error: OpenVPN plugin missing.\nPlease install 'net-vpn/networkmanager-openvpn' package.";
                } else {
                        root.vpnStatus = "❌ Error: " + err;
                }
            } else {
                root.vpnStatus = "✅ VPN Added Successfully!";
                root.success();
                vpnSuccessCloseTimer.start();
            }
            vpnCreationProcess.errBuf = "";
        }
    }
    
    Timer { id: vpnSuccessCloseTimer; interval: 1500; repeat: false; onTriggered: root.close() }
}
