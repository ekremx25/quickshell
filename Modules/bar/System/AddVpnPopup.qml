import QtQuick
import Qt.labs.platform
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../Widgets"
import "../../../Services" as S
import "../../../Services/core/Log.js" as Log

// Settings → Network → Add VPN. Imports the WireGuard (.conf) or OpenVPN
// (.ovpn) file from a VPN provider through scripts/vpn_manager.py, which
// validates the file, adds the profile without activating it, and keeps keys
// and passwords off the command line.
PanelWindow {
    PopupEntrance {}  // liquid ring open animation
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // Above Settings, which lives on the Top layer.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:add-vpn"
    visible: false

    signal success(string uuid, string name)

    readonly property string helperPath: (Quickshell.env("HOME") || "") + "/.config/quickshell/scripts/vpn_manager.py"
    readonly property color accent: SettingsPalette.readableAccent(Theme.primary)

    property string vpnType: "wireguard"          // wireguard | openvpn
    property string filePath: ""
    property var fileInfo: null                   // result of `vpn_manager.py inspect`
    property string fileError: ""
    property string statusText: ""
    property bool statusIsError: false
    property bool busy: inspectProc.running || importProc.running

    readonly property bool needsUsername: vpnType === "openvpn" && fileInfo !== null && fileInfo.needsCredentials === true
    readonly property bool canAdd: !busy && fileInfo !== null && nameInput.text.trim().length > 0
                                   && (!needsUsername || userInput.text.trim().length > 0)

    function open() {
        vpnType = "wireguard";
        resetFile();
        nameInput.text = "";
        userInput.text = "";
        passInput.text = "";
        connectNowBox.checked = true;
        autoconnectBox.checked = false;
        statusText = "";
        visible = true;
    }

    function close() {
        if (importProc.running) return;  // never abandon a half-finished import
        filePickerOverlay.visible = false;
        visible = false;
        passInput.text = "";
    }

    function resetFile() {
        filePath = "";
        fileInfo = null;
        fileError = "";
    }

    function selectType(type) {
        if (type === vpnType || busy) return;
        vpnType = type;
        resetFile();
        statusText = "";
    }

    function openFilePicker() {
        filePickerOverlay.visible = true;
        // Setting currentPath makes the picker list that directory.
        vpnFilePicker.currentPath = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "");
    }

    function inspectFile(path) {
        resetFile();
        filePath = path;
        statusText = "";
        inspectProc.buffer = "";
        inspectProc.command = ["python3", "-I", root.helperPath, "inspect", "--type", root.vpnType, "--file", path];
        inspectProc.running = true;
    }

    function addVpn() {
        if (!canAdd) return;
        statusText = "Adding " + nameInput.text.trim() + "…";
        statusIsError = false;
        var command = ["python3", "-I", root.helperPath, "import",
                       "--type", root.vpnType, "--file", root.filePath,
                       "--name", nameInput.text.trim(),
                       "--autoconnect", autoconnectBox.checked ? "yes" : "no"];
        if (root.vpnType === "openvpn") {
            command.push("--username", userInput.text.trim());
            if (passInput.text.length > 0) command.push("--password-stdin");
        }
        importProc.buffer = "";
        importProc.sendPassword = root.vpnType === "openvpn" && passInput.text.length > 0;
        importProc.command = command;
        importProc.running = true;
    }

    function parseResult(buffer) {
        try {
            return JSON.parse(String(buffer || "").trim().split("\n").pop());
        } catch (e) {
            return { ok: false, error: "Unexpected answer from the VPN helper." };
        }
    }

    // ── Reusable bits ──
    component FieldLabel: Text {
        color: SettingsPalette.subtext
        font.pixelSize: 12
        font.family: Theme.fontFamily
    }

    component InputBox: Rectangle {
        id: box
        property alias input: field
        property alias text: field.text
        property string placeholder: ""
        property bool secret: false
        Layout.fillWidth: true
        height: 40; radius: 8
        color: Theme.withAlpha(Theme.text, 0.04)
        border.width: 1
        border.color: field.activeFocus ? root.accent : Theme.withAlpha(Theme.text, 0.12)
        TextInput {
            id: field
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: SettingsPalette.text
            font.pixelSize: 13; font.family: Theme.fontFamily
            echoMode: box.secret ? TextInput.Password : TextInput.Normal
            selectByMouse: true
            clip: true
            enabled: !root.busy
            Keys.onReturnPressed: root.addVpn()
            Keys.onEscapePressed: root.close()
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left; anchors.leftMargin: 12
            text: box.placeholder
            visible: field.text.length === 0 && !field.activeFocus
            color: SettingsPalette.overlay
            font.pixelSize: 13; font.family: Theme.fontFamily
        }
    }

    component CheckRow: Item {
        id: check
        property bool checked: false
        property string label: ""
        property string hint: ""
        Layout.fillWidth: true
        implicitHeight: checkCol.implicitHeight
        RowLayout {
            anchors.fill: parent
            spacing: 10
            Rectangle {
                Layout.alignment: Qt.AlignTop
                width: 18; height: 18; radius: 5
                color: check.checked ? root.accent : "transparent"
                border.width: 1
                border.color: check.checked ? root.accent : Theme.withAlpha(Theme.text, 0.3)
                Text {
                    anchors.centerIn: parent
                    text: "✓"; visible: check.checked
                    color: SettingsPalette.foregroundFor(root.accent); font.pixelSize: 12; font.bold: true
                }
            }
            ColumnLayout {
                id: checkCol
                Layout.fillWidth: true
                spacing: 2
                Text { text: check.label; color: SettingsPalette.text; font.pixelSize: 13; font.family: Theme.fontFamily }
                Text {
                    Layout.fillWidth: true
                    visible: check.hint.length > 0
                    text: check.hint; wrapMode: Text.WordWrap
                    color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.fontFamily
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: !root.busy
            onClicked: check.checked = !check.checked
        }
    }

    // ── Dimmer ──
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ── Dialog ──
    Rectangle {
        id: dialog
        width: 560
        height: Math.min(contentCol.implicitHeight + 48, root.height - 80)
        anchors.centerIn: parent
        color: Theme.background
        radius: 16
        border.color: Theme.withAlpha(Theme.text, 0.1)
        border.width: 1
        clip: true

        MouseArea { anchors.fill: parent }  // keep clicks off the dimmer

        Flickable {
            anchors.fill: parent; anchors.margins: 24
            contentHeight: contentCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: contentCol
                width: parent.width
                spacing: 16

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: 4
                        Text { text: "Add VPN"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 18; font.family: Theme.fontFamily }
                        Text {
                            text: "Import the configuration file from your VPN provider."
                            color: SettingsPalette.subtext; font.pixelSize: 12; font.family: Theme.fontFamily
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "✕"; color: SettingsPalette.subtext; font.pixelSize: 16
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.withAlpha(Theme.text, 0.1) }

                // 1. Type
                FieldLabel { text: "VPN type" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: [
                            { value: "wireguard", label: "WireGuard", ext: ".conf file" },
                            { value: "openvpn", label: "OpenVPN", ext: ".ovpn file" }
                        ]
                        Rectangle {
                            required property var modelData
                            readonly property bool selected: root.vpnType === modelData.value
                            Layout.fillWidth: true
                            height: 52; radius: 10
                            color: selected ? Theme.withAlpha(Theme.primary, 0.16) : Theme.withAlpha(Theme.text, 0.04)
                            border.width: 1
                            border.color: selected ? root.accent : Theme.withAlpha(Theme.text, 0.1)
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                Text { Layout.alignment: Qt.AlignHCenter; text: parent.parent.modelData.label; color: SettingsPalette.text; font.pixelSize: 13; font.bold: true; font.family: Theme.fontFamily }
                                Text { Layout.alignment: Qt.AlignHCenter; text: parent.parent.modelData.ext; color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.fontFamily }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectType(parent.modelData.value)
                            }
                        }
                    }
                }

                // 2. File
                FieldLabel { text: "Configuration file" }
                Rectangle {
                    Layout.fillWidth: true
                    height: 44; radius: 10
                    color: fileMA.containsMouse && !root.busy ? Theme.withAlpha(Theme.primary, 0.12) : Theme.withAlpha(Theme.text, 0.04)
                    border.width: 1
                    border.color: root.fileError ? Theme.withAlpha(Theme.red, 0.6)
                                 : root.fileInfo ? Theme.withAlpha(Theme.green, 0.5) : Theme.withAlpha(Theme.text, 0.12)
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 8
                        Text { text: "󰈔"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: root.accent }
                        Text {
                            Layout.fillWidth: true
                            text: root.filePath ? root.filePath.split("/").pop()
                                                : "Choose the " + (root.vpnType === "wireguard" ? ".conf" : ".ovpn") + " file…"
                            elide: Text.ElideMiddle
                            color: root.filePath ? SettingsPalette.text : SettingsPalette.subtext
                            font.pixelSize: 13; font.family: Theme.fontFamily
                        }
                        Text {
                            text: inspectProc.running ? "Checking…" : (root.filePath ? "Change" : "Browse")
                            color: root.accent; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily
                        }
                    }
                    MouseArea {
                        id: fileMA
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: root.busy ? Qt.BusyCursor : Qt.PointingHandCursor
                        onClicked: if (!root.busy) root.openFilePicker()
                    }
                }

                Text {
                    visible: root.fileError.length > 0
                    Layout.fillWidth: true
                    text: "⚠ " + root.fileError
                    wrapMode: Text.WordWrap
                    color: SettingsPalette.readableAccent(Theme.red); font.pixelSize: 12; font.family: Theme.fontFamily
                }

                // File summary
                Rectangle {
                    visible: root.fileInfo !== null
                    Layout.fillWidth: true
                    implicitHeight: summaryCol.implicitHeight + 20
                    radius: 10
                    color: Theme.withAlpha(Theme.text, 0.03)
                    ColumnLayout {
                        id: summaryCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 4
                        Text {
                            Layout.fillWidth: true
                            text: "Server: " + (root.fileInfo && root.fileInfo.server ? root.fileInfo.server : "not specified")
                            elide: Text.ElideRight
                            color: SettingsPalette.text; font.pixelSize: 12; font.family: Theme.fontFamily
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: root.fileInfo && root.fileInfo.fullTunnel
                                  ? "All internet traffic will go through this VPN while it is connected."
                                  : "Only the networks listed in the file will go through this VPN."
                            color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.fontFamily
                        }
                    }
                }

                // 3. Name
                FieldLabel { text: "Name" }
                InputBox { id: nameInput; objectName: "vpnNameInput"; placeholder: "e.g. Germany" }

                // 4. Credentials (OpenVPN)
                ColumnLayout {
                    visible: root.vpnType === "openvpn" && root.fileInfo !== null
                    Layout.fillWidth: true
                    spacing: 8
                    FieldLabel {
                        text: root.needsUsername ? "Login (required by this server)" : "Login (only if your provider gave you one)"
                    }
                    InputBox { id: userInput; objectName: "vpnUserInput"; placeholder: "Username" }
                    InputBox { id: passInput; objectName: "vpnPassInput"; placeholder: "Password"; secret: true }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "The password is stored by NetworkManager so connecting does not ask for it."
                        color: SettingsPalette.overlay; font.pixelSize: 11; font.family: Theme.fontFamily
                    }
                }

                // 5. Options
                CheckRow { id: connectNowBox; objectName: "vpnConnectNow"; checked: true; label: "Connect now" }
                CheckRow {
                    id: autoconnectBox
                    label: "Connect automatically"
                    hint: "Turn this VPN on by itself whenever the computer goes online."
                }

                // Status
                Text {
                    visible: root.statusText.length > 0
                    Layout.fillWidth: true
                    text: root.statusText
                    wrapMode: Text.WordWrap
                    color: root.statusIsError ? SettingsPalette.readableAccent(Theme.red) : SettingsPalette.subtext
                    font.pixelSize: 12; font.family: Theme.fontFamily
                }

                // Actions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 96; height: 38; radius: 8
                        color: cancelMA.containsMouse ? Theme.withAlpha(Theme.text, 0.14) : Theme.withAlpha(Theme.text, 0.08)
                        opacity: importProc.running ? 0.5 : 1
                        Text { anchors.centerIn: parent; text: "Cancel"; color: SettingsPalette.text; font.pixelSize: 13; font.family: Theme.fontFamily }
                        MouseArea { id: cancelMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
                    }
                    Rectangle {
                        width: 120; height: 38; radius: 8
                        color: root.canAdd ? (addMA.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary) : Theme.withAlpha(Theme.text, 0.08)
                        Text {
                            anchors.centerIn: parent
                            text: importProc.running ? "Adding…" : "Add VPN"
                            color: root.canAdd ? Theme.foregroundFor(Theme.primary) : SettingsPalette.overlay
                            font.pixelSize: 13; font.bold: true; font.family: Theme.fontFamily
                        }
                        MouseArea {
                            id: addMA
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: root.canAdd ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.addVpn()
                        }
                    }
                }
            }
        }
    }

    // ── File picker ──
    Rectangle {
        id: filePickerOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: false
        MouseArea { anchors.fill: parent }  // block clicks underneath

        FilePicker {
            id: vpnFilePicker
            anchors.centerIn: parent
            width: Math.min(640, parent.width - 48)
            height: Math.min(520, parent.height - 48)
            extensions: root.vpnType === "wireguard" ? ["conf"] : ["ovpn", "conf"]
            title: root.vpnType === "wireguard" ? "Select a WireGuard .conf file" : "Select an OpenVPN .ovpn file"
            onFileSelected: (path) => {
                filePickerOverlay.visible = false;
                root.inspectFile(path);
            }
            onCanceled: filePickerOverlay.visible = false
        }
    }

    // ── Helpers ──
    Process {
        id: inspectProc
        property string buffer: ""
        stdout: SplitParser { onRead: data => inspectProc.buffer += data + "\n" }
        stderr: SplitParser { onRead: data => Log.warn("AddVpnPopup", data) }
        onExited: {
            var result = root.parseResult(inspectProc.buffer);
            if (result.ok) {
                root.fileInfo = result;
                if (nameInput.text.trim().length === 0) nameInput.text = result.suggestedName || "";
            } else {
                root.fileError = result.error || "This file could not be read.";
            }
        }
    }

    Process {
        id: importProc
        property string buffer: ""
        property bool sendPassword: false
        stdinEnabled: true
        stdout: SplitParser { onRead: data => importProc.buffer += data + "\n" }
        stderr: SplitParser { onRead: data => Log.warn("AddVpnPopup", data) }
        onStarted: {
            // The password goes through stdin so it never shows up in `ps`.
            if (importProc.sendPassword) importProc.write(passInput.text);
            importProc.stdinEnabled = false;
        }
        onExited: {
            importProc.stdinEnabled = true;
            var result = root.parseResult(importProc.buffer);
            if (!result.ok) {
                root.statusText = result.error || "The VPN could not be added.";
                root.statusIsError = true;
                return;
            }
            S.VpnService.refreshAll();
            if (connectNowBox.checked) S.VpnService.connect(result.uuid);
            root.success(result.uuid, result.name);
            root.close();
        }
    }
}
