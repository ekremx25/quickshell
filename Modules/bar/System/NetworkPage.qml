import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"
import "../../../Widgets"

Item {
    id: networkPage


    // ── Properties ──
    property string ifaceName: ""
    property string ipAddr: ""
    property string gateway: ""
    property string connName: ""
    property string connStatus: "Checking..."
    property string macAddr: ""
    property string dns: ""
    property string connType: "" // ethernet / wifi

    // IPv4/IPv6/DNS/Proxy method states
    property string ipv4Method: "auto"
    property string ipv6Method: "auto"
    property string dnsMethod: "auto"
    property string proxyMethod: "none"
    property string mtuValue: "1500"
    property string macMode: "default"

    // WiFi
    property var wifiList: []
    property string connectingSsid: ""

    function refresh() {
        nmcliProc.running = false;
        nmcliProc.running = true;
        refreshDelayTimer.start();
    }

    // ═══════════ PROCESSES ═══════════

    // Device status
    Process {
        id: nmcliProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { nmcliProc.buf += data + "\n"; } }
        onExited: { parseDeviceStatus(nmcliProc.buf); nmcliProc.buf = ""; }
    }

    // IP detection
    Process {
        id: ipProc
        command: ["sh", "-c", "ip -4 addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}'"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { ipProc.buf = data.trim(); } }
        onExited: { networkPage.ipAddr = ipProc.buf; ipProc.buf = ""; }
    }

    // Gateway
    Process {
        id: gwProc
        command: ["sh", "-c", "ip route | grep default | awk '{print $3}' | head -1"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { gwProc.buf = data.trim(); } }
        onExited: { networkPage.gateway = gwProc.buf; gwProc.buf = ""; }
    }

    // MAC address
    Process {
        id: macProc
        property string iface: ""
        command: ["sh", "-c", "cat /sys/class/net/" + iface + "/address 2>/dev/null || echo '--'"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { macProc.buf = data.trim(); } }
        onExited: { networkPage.macAddr = macProc.buf; macProc.buf = ""; }
    }

    // DNS info
    Process {
        id: dnsProc
        command: ["sh", "-c", "nmcli -t -f IP4.DNS connection show --active 2>/dev/null | head -1 | cut -d: -f2"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { dnsProc.buf = data.trim(); } }
        onExited: { networkPage.dns = dnsProc.buf || "Automatic"; dnsProc.buf = ""; }
    }

    // Connection details (ipv4.method, ipv6.method, proxy, MTU)
    Process {
        id: connDetailProc
        property string conn: ""
        command: ["sh", "-c", "nmcli -t -f ipv4.method,ipv6.method,802-3-ethernet.mtu connection show '" + conn + "' 2>/dev/null"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { connDetailProc.buf += data + "\n"; } }
        onExited: {
            var lines = connDetailProc.buf.split("\n");
            for (var i = 0; i < lines.length; i++) {
                var parts = lines[i].split(":");
                if (parts[0] === "ipv4.method") networkPage.ipv4Method = parts[1] || "auto";
                if (parts[0] === "ipv6.method") networkPage.ipv6Method = parts[1] || "auto";
                if (parts[0] === "802-3-ethernet.mtu") networkPage.mtuValue = (parts[1] && parts[1] !== "" && parts[1] !== "0") ? parts[1] : "1500";
            }
            connDetailProc.buf = "";
        }
    }



    // WiFi scan
    Process {
        id: wifiScanProc
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,BARS,ACTIVE", "device", "wifi", "list", "--rescan", "no"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { wifiScanProc.buf += data + "\n"; } }
        onExited: { parseWifiList(wifiScanProc.buf); wifiScanProc.buf = ""; }
    }

    // WiFi connect
    Process {
        id: connectProc
        command: []
        onExited: {
            networkPage.connectingSsid = "";
            nmcliProc.buf = ""; nmcliProc.running = false; nmcliProc.running = true;
            wifiScanProc.buf = ""; wifiScanProc.running = false; wifiScanProc.running = true;
        }
    }



    // Disconnect
    Process {
        id: disconnectProc
        command: []
        onExited: {
            nmcliProc.buf = ""; nmcliProc.running = false; nmcliProc.running = true;
            ipProc.buf = ""; ipProc.running = false; ipProc.running = true;
        }
    }

    // Apply network setting
    property string applyStatus: ""
    property bool applyError: false

    // Modify connection settings (no shell - direct args)
    Process {
        id: applyProc
        command: []
        property string errBuf: ""
        stdout: SplitParser { onRead: (data) => console.log("[net-apply]: " + data) }
        stderr: SplitParser { onRead: (data) => { applyProc.errBuf += data + " "; console.log("[net-apply err]: " + data); } }
        onExited: (code) => {
            if (code !== 0) {
                networkPage.applyStatus = "❌ Modify error: " + applyProc.errBuf;
                networkPage.applyError = true;
            } else {
                // Step 2: Bring connection up with new settings
                networkPage.applyStatus = "⏳ Restarting connection...";
                connUpProc.errBuf = "";
                connUpProc.command = ["nmcli", "connection", "up", networkPage.connName];
                connUpProc.running = false;
                connUpProc.running = true;
            }
            applyProc.errBuf = "";
        }
    }

    // Bring connection up after modify
    Process {
        id: connUpProc
        command: []
        property string errBuf: ""
        stdout: SplitParser { onRead: (data) => console.log("[conn-up]: " + data) }
        stderr: SplitParser { onRead: (data) => { connUpProc.errBuf += data + " "; console.log("[conn-up err]: " + data); } }
        onExited: (code) => {
            if (code !== 0) {
                networkPage.applyStatus = "❌ Connection error: " + connUpProc.errBuf;
                networkPage.applyError = true;
            } else {
                networkPage.applyStatus = "✅ IP changed successfully!";
                networkPage.applyError = false;
                refreshDelayTimer.start();
            }
            connUpProc.errBuf = "";
        }
    }

    Timer {
        id: refreshDelayTimer
        interval: 2000; repeat: false
        onTriggered: {
            nmcliProc.buf = ""; nmcliProc.running = false; nmcliProc.running = true;
            ipProc.buf = ""; ipProc.running = false; ipProc.running = true;
            gwProc.buf = ""; gwProc.running = false; gwProc.running = true;
        }
    }

    // ═══════════ PARSERS ═══════════
    function parseDeviceStatus(text) {
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split(":");
            if (parts.length >= 4 && parts[2] === "connected") {
                ifaceName = parts[0];
                connName = parts[3];
                connType = parts[1];
                connStatus = "Connected";
                // Get details
                macProc.iface = parts[0];
                macProc.buf = ""; macProc.running = false; macProc.running = true;
                connDetailProc.conn = parts[3];
                connDetailProc.buf = ""; connDetailProc.running = false; connDetailProc.running = true;
                return;
            }
        }
        connStatus = "Disconnected";
    }

    function parseWifiList(text) {
        var lines = text.split("\n");
        var list = [];
        var seen = {};
        for (var i = 0; i < lines.length; i++) {
            var match = lines[i].match(/^(.*):(\\d+):(.*):(.*):(yes|no)$/);
            if (!match) continue;
            var s = match[1].replace(/\\:/g, ":");
            var sig = parseInt(match[2]);
            var sec = match[3];
            var bars = match[4];
            var act = match[5] === "yes";
            if (!s || seen[s]) continue;
            seen[s] = true;
            list.push({ ssid: s, signal: sig, security: sec, bars: bars, active: act });
        }
        list.sort(function(a, b) { return a.active ? -1 : b.active ? 1 : b.signal - a.signal; });
        if (list.length > 0) wifiList = list;
    }

    // ═══════════ LIFECYCLE ═══════════
    Component.onCompleted: {
        nmcliProc.running = true;
        ipProc.running = true;
        gwProc.running = true;
        dnsProc.running = true;
        wifiScanProc.running = true;
    }

    Timer {
        interval: 10000; running: networkPage.visible; repeat: true
        onTriggered: {
            nmcliProc.buf = ""; nmcliProc.running = false; nmcliProc.running = true;
            ipProc.buf = ""; ipProc.running = false; ipProc.running = true;
            dnsProc.buf = ""; dnsProc.running = false; dnsProc.running = true;
        }
    }

    // ═══════════ UI ═══════════
    Flickable {
        anchors.fill: parent
        contentHeight: mainColumn.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainColumn
            width: parent.width
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 20; anchors.rightMargin: 20
            anchors.top: parent.top; anchors.topMargin: 20
            spacing: 16

            // ═══════════ 1. ETHERNET / WIFI STATUS ═══════════
            Rectangle {
                id: ethCard
                Layout.fillWidth: true
                height: ethCol.height + 28
                color: Theme.surface
                radius: 12
                border.color: Qt.rgba(255,255,255,0.04)
                border.width: 1

                ColumnLayout {
                    id: ethCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 14
                    spacing: 10

                    // Title
                    RowLayout {
                        spacing: 8
                        Text { text: connType === "wifi" ? "󰖩" : "󰈀"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
                        Text { text: connType === "wifi" ? "WiFi" : "Ethernet"; font.bold: true; font.pixelSize: 16; color: Theme.text }
                    }

                    // Info line
                    Rectangle {
                        Layout.fillWidth: true; height: 36
                        color: Qt.rgba(49/255, 50/255, 68/255, 0.4); radius: 8
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 12
                            Text { text: "Interface:"; color: Theme.subtext; font.pixelSize: 12 }
                            Text { text: networkPage.ifaceName || "—"; color: Theme.text; font.bold: true; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font" }
                            Text { text: "IP:"; color: Theme.subtext; font.pixelSize: 12 }
                            Text { text: networkPage.ipAddr || "—"; color: Theme.text; font.bold: true; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font" }
                            Item { Layout.fillWidth: true }
                        }
                    }

                    // Buttons
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 60; height: 32; radius: 8
                            color: editMA.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { anchors.centerIn: parent; text: "Edit"; color: "#1e1e2e"; font.pixelSize: 12; font.bold: true }
                            MouseArea {
                                id: editMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { editConnPopup.open(); }
                            }
                        }

                        Rectangle {
                            width: 90; height: 32; radius: 8
                            color: discMA.containsMouse ? Qt.lighter("#f38ba8", 1.15) : Qt.rgba(243/255, 139/255, 168/255, 0.2)
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { anchors.centerIn: parent; text: "Disconnect"; color: "#f38ba8"; font.pixelSize: 12; font.bold: true }
                            MouseArea {
                                id: discMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (networkPage.ifaceName) { disconnectProc.command = ["nmcli", "device", "disconnect", networkPage.ifaceName]; disconnectProc.running = true; } }
                            }
                        }
                    }
                }
            }



            // ═══════════ 3. DNS CONFIGURATION ═══════════
            Rectangle {
                Layout.fillWidth: true
                height: dnsCol.height + 28
                color: Theme.surface
                radius: 12
                border.color: Qt.rgba(255,255,255,0.04)
                border.width: 1

                ColumnLayout {
                    id: dnsCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        spacing: 8
                        Text { text: "󰇧"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"; color: "#cba6f7" }
                        Text { text: "DNS Configuration"; font.bold: true; font.pixelSize: 16; color: Theme.text }
                    }

                    RowLayout {
                        spacing: 10
                        Text { text: "DNS Method:"; color: Theme.subtext; font.pixelSize: 12 }
                        SegmentButton {
                            options: ["Automatic", "Manual"]
                            selectedIndex: networkPage.dnsMethod === "auto" ? 0 : 1
                            onSelected: (idx) => {
                                networkPage.dnsMethod = idx === 0 ? "auto" : "manual";
                            }
                        }
                    }
                }
            }

            // ═══════════ 4. IP CONFIGURATION ═══════════
            Rectangle {
                Layout.fillWidth: true
                height: ipCol.height + 28
                color: Theme.surface
                radius: 12
                border.color: Qt.rgba(255,255,255,0.04)
                border.width: 1

                ColumnLayout {
                    id: ipCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 14
                    spacing: 14

                    RowLayout {
                        spacing: 8
                        Text { text: ""; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: "#fab387" }
                        Text { text: "IP Configuration"; font.bold: true; font.pixelSize: 16; color: Theme.text }
                    }

                    // IPv4
                    Text { text: "IPv4"; color: Theme.text; font.bold: true; font.pixelSize: 13 }
                    RowLayout {
                        spacing: 10
                        Text { text: "Method:"; color: Theme.subtext; font.pixelSize: 12 }
                        SegmentButton {
                            options: ["Automatic", "Manual", "Link-Local"]
                            selectedIndex: networkPage.ipv4Method === "auto" ? 0 : networkPage.ipv4Method === "manual" ? 1 : 2
                            onSelected: (idx) => {
                                networkPage.ipv4Method = idx === 0 ? "auto" : idx === 1 ? "manual" : "link-local";
                            }
                        }
                    }

                    // IPv6
                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.04) }
                    Text { text: "IPv6"; color: Theme.text; font.bold: true; font.pixelSize: 13 }
                    RowLayout {
                        spacing: 10
                        Text { text: "Method:"; color: Theme.subtext; font.pixelSize: 12 }
                        SegmentButton {
                            options: ["Automatic", "Manual", "Ignore"]
                            selectedIndex: networkPage.ipv6Method === "auto" ? 0 : networkPage.ipv6Method === "manual" ? 1 : 2
                            onSelected: (idx) => {
                                networkPage.ipv6Method = idx === 0 ? "auto" : idx === 1 ? "manual" : "ignore";
                            }
                        }
                    }
                }
            }

            // ═══════════ 5. PROXY CONFIGURATION ═══════════
            Rectangle {
                Layout.fillWidth: true
                height: proxyCol.height + 28
                color: Theme.surface
                radius: 12
                border.color: Qt.rgba(255,255,255,0.04)
                border.width: 1

                ColumnLayout {
                    id: proxyCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        spacing: 8
                        Text { text: ""; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: "#89b4fa" }
                        Text { text: "Proxy Configuration"; font.bold: true; font.pixelSize: 16; color: Theme.text }
                    }

                    RowLayout {
                        spacing: 10
                        Text { text: "Proxy Method:"; color: Theme.subtext; font.pixelSize: 12 }
                        SegmentButton {
                            options: ["None", "Manual", "Automatic"]
                            selectedIndex: networkPage.proxyMethod === "none" ? 0 : networkPage.proxyMethod === "manual" ? 1 : 2
                            onSelected: (idx) => {
                                networkPage.proxyMethod = idx === 0 ? "none" : idx === 1 ? "manual" : "auto";
                            }
                        }
                    }
                }
            }

            // ═══════════ 6. ADVANCED SETTINGS ═══════════
            Rectangle {
                Layout.fillWidth: true
                height: advancedCol.height + 28
                color: Theme.surface
                radius: 12
                border.color: Qt.rgba(255,255,255,0.04)
                border.width: 1

                ColumnLayout {
                    id: advancedCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 14
                    spacing: 14

                    RowLayout {
                        spacing: 8
                        Text { text: ""; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: "#f5c2e7" }
                        Text { text: "Advanced Settings"; font.bold: true; font.pixelSize: 16; color: Theme.text }
                    }

                    // MTU
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12

                        Text { text: "MTU:"; color: Theme.subtext; font.pixelSize: 12 }

                        Rectangle {
                            width: 100; height: 36; radius: 8
                            color: Qt.rgba(49/255, 50/255, 68/255, 0.6)
                            border.color: mtuInput.activeFocus ? Theme.primary : "transparent"
                            border.width: mtuInput.activeFocus ? 2 : 0

                            TextInput {
                                id: mtuInput
                                anchors.fill: parent; anchors.margins: 8
                                text: networkPage.mtuValue
                                color: Theme.text; font.pixelSize: 13
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                onTextChanged: networkPage.mtuValue = text
                            }
                        }

                        Text { text: "(576-9000, default: 1500)"; color: Theme.overlay; font.pixelSize: 11 }
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 60; height: 30; radius: 8
                            color: mtuApplyMA.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { anchors.centerIn: parent; text: "Apply"; color: "#1e1e2e"; font.pixelSize: 11; font.bold: true }
                            MouseArea {
                                id: mtuApplyMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (networkPage.connName) {
                                        applyProc.command = ["nmcli", "connection", "modify", networkPage.connName, "802-3-ethernet.mtu", networkPage.mtuValue];
                                        applyProc.running = false;
                                        applyProc.running = true;
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.04) }

                    // MAC Address
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12

                        Text { text: "MAC Address:"; color: Theme.subtext; font.pixelSize: 12 }

                        SegmentButton {
                            options: ["Default", "Cloned"]
                            selectedIndex: networkPage.macMode === "default" ? 0 : 1
                            onSelected: (idx) => {
                                networkPage.macMode = idx === 0 ? "default" : "cloned";
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 60; height: 30; radius: 8
                            color: macApplyMA.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { anchors.centerIn: parent; text: "Apply"; color: "#1e1e2e"; font.pixelSize: 11; font.bold: true }
                            MouseArea {
                                id: macApplyMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (networkPage.connName) {
                                        var macVal = networkPage.macMode === "default" ? "" : networkPage.macAddr;
                                        applyProc.command = ["nmcli", "connection", "modify", networkPage.connName, "802-3-ethernet.cloned-mac-address", macVal || "permanent"];
                                        applyProc.running = false;
                                        applyProc.running = true;
                                    }
                                }
                            }
                        }
                    }

                    // Show current MAC
                    Text {
                        text: "Current: " + (networkPage.macAddr || "—")
                        color: Theme.overlay; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }



            // ═══════════ 7. WIFI LIST ═══════════
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.06) }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Available Networks"; color: Theme.subtext; font.pixelSize: 12; font.bold: true }
                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 24; height: 24; radius: 6
                    color: refreshMa.containsMouse ? Theme.surface : "transparent"
                    Text { anchors.centerIn: parent; text: "󰑐"; font.family: "JetBrainsMono Nerd Font"; color: Theme.subtext; font.pixelSize: 14 }
                    MouseArea {
                        id: refreshMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wifiScanProc.buf = "";
                            wifiScanProc.running = false;
                            wifiScanProc.running = true;
                        }
                    }
                }
            }

            Repeater {
                model: networkPage.wifiList

                Rectangle {
                    id: wifiDelegate
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    height: wifiExpanded ? 96 : 48
                    color: modelData.active ? Qt.rgba(137/255, 180/255, 250/255, 0.15)
                         : (wifiHoverMa.containsMouse || wifiExpanded ? Qt.rgba(255,255,255,0.05) : "transparent")
                    radius: 8; clip: true

                    property bool wifiExpanded: false
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                    RowLayout {
                        id: wifiHeader
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        height: 48; anchors.margins: 12; spacing: 12

                        Text {
                            text: "󰖩"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"
                            color: modelData.active ? Theme.primary : Theme.text
                        }
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: modelData.ssid; color: modelData.active ? Theme.primary : Theme.text
                                font.bold: modelData.active; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                text: (modelData.security !== "" ? "🔒 " + modelData.security : "Açık") + " • " + modelData.signal + "%"
                                color: Theme.subtext; font.pixelSize: 10
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: modelData.bars; color: modelData.active ? Theme.primary : Theme.subtext; font.family: "DejaVu Sans" }
                    }

                    MouseArea {
                        id: wifiHoverMa
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        height: 48; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (!modelData.active) wifiDelegate.wifiExpanded = !wifiDelegate.wifiExpanded; }
                    }

                    RowLayout {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: wifiHeader.bottom; anchors.topMargin: 4
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        height: 36; spacing: 8; visible: wifiDelegate.wifiExpanded

                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 120; height: 36; radius: 6
                            color: networkPage.connectingSsid === modelData.ssid ? Theme.surface
                                 : wifiConnMA.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

                            Text {
                                anchors.centerIn: parent
                                text: networkPage.connectingSsid === modelData.ssid ? "Bağlanıyor..." : "Bağlan"
                                color: networkPage.connectingSsid === modelData.ssid ? Theme.subtext : "#1e1e2e"
                                font.bold: true; font.pixelSize: 12
                            }
                            MouseArea {
                                id: wifiConnMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: networkPage.connectingSsid === ""
                                onClicked: {
                                    networkPage.connectingSsid = modelData.ssid;
                                    connectProc.command = ["nmcli", "device", "wifi", "connect", modelData.ssid];
                                    connectProc.running = true;
                                }
                            }
                        }
                    }
                }
            }

            Item { height: 20 }
        }
    }

    // ═══════════ POPUPS ═══════════

    // ── Edit Connection Popup ──
    Rectangle {
        id: editConnPopup
        anchors.fill: parent
        color: Qt.rgba(0,0,0,0.6)
        z: 999
        visible: false
        
        property bool active: false
        onVisibleChanged: {
            if (visible) {
                // Load current values
                ipv4AddrInput.text = networkPage.ipAddr.split("/")[0] || "";
                ipv4GwInput.text = networkPage.gateway;
                dnsInput.text = networkPage.dns;
                // Default to Manual if values exist, else Auto
                // Simplification for now: check if IP is set
                // networkPage.ipv4Method = (networkPage.ipAddr !== "") ? "manual" : "auto";
            }
        }

        function open() { visible = true; active = true; }
        function close() { visible = false; active = false; }

        MouseArea { anchors.fill: parent; onClicked: editConnPopup.close() } // Click outside to close

        Rectangle {
            width: 500; height: 600
            anchors.centerIn: parent
            color: "#1e1e2e"
            radius: 16
            border.color: Qt.rgba(255,255,255,0.1)
            border.width: 1

            MouseArea { anchors.fill: parent } // Block clicks

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 24
                spacing: 20

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Edit Connection"; color: Theme.text; font.bold: true; font.pixelSize: 16 }
                    Item { Layout.fillWidth: true }
                    Text { text: "✕"; color: Theme.subtext; font.pixelSize: 16; MouseArea { anchors.fill: parent; onClicked: editConnPopup.close(); cursorShape: Qt.PointingHandCursor } }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.1) }
                
                // Content
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 20
                    
                    // Connection Name Display
                    Rectangle {
                        Layout.fillWidth: true; height: 40
                        color: Qt.rgba(255,255,255,0.05); radius: 8
                        border.color: Qt.rgba(255,255,255,0.1)
                        TextInput { 
                            anchors.fill: parent; anchors.margins: 12
                            text: networkPage.connName || "Unknown Connection"
                            color: Theme.subtext; font.italic: true
                            readOnly: true
                            verticalAlignment: TextInput.AlignVCenter
                        }
                    }

                    // IPv4 Section
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 12
                        Text { text: "IPv4 Configuration"; color: Theme.text; font.bold: true; font.pixelSize: 14 }
                        
                        RowLayout {
                            spacing: 12
                            Text { text: "Method:"; color: Theme.subtext; Layout.preferredWidth: 80 }
                            SegmentButton {
                                options: ["Automatic", "Manual", "Link-Local"]
                                selectedIndex: networkPage.ipv4Method === "auto" ? 0 : networkPage.ipv4Method === "manual" ? 1 : 2
                                onSelected: (idx) => networkPage.ipv4Method = idx === 0 ? "auto" : idx === 1 ? "manual" : "link-local"
                            }
                        }

                        // IP & Gateway
                        ColumnLayout {
                            visible: networkPage.ipv4Method === "manual"
                            Layout.fillWidth: true; spacing: 10
                            
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "IP Address:"; color: Theme.subtext; Layout.preferredWidth: 80 }
                                Rectangle {
                                    Layout.fillWidth: true; height: 36; radius: 8
                                    color: Qt.rgba(0,0,0,0.2); border.color: ipv4AddrInput.activeFocus ? Theme.primary : "transparent"; border.width: 1
                                    TextInput { id: ipv4AddrInput; anchors.fill: parent; anchors.margins: 8; color: Theme.text; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Gateway:"; color: Theme.subtext; Layout.preferredWidth: 80 }
                                Rectangle {
                                    Layout.fillWidth: true; height: 36; radius: 8
                                    color: Qt.rgba(0,0,0,0.2); border.color: ipv4GwInput.activeFocus ? Theme.primary : "transparent"; border.width: 1
                                    TextInput { id: ipv4GwInput; anchors.fill: parent; anchors.margins: 8; color: Theme.text; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.05) }

                    // IPv6 Section (Simplified)
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 12
                        Text { text: "IPv6 Configuration"; color: Theme.text; font.bold: true; font.pixelSize: 14 }
                        
                        RowLayout {
                            spacing: 12
                            Text { text: "Method:"; color: Theme.subtext; Layout.preferredWidth: 80 }
                            SegmentButton {
                                options: ["Automatic", "Manual", "Ignore"]
                                selectedIndex: networkPage.ipv6Method === "auto" ? 0 : networkPage.ipv6Method === "manual" ? 1 : 2
                                onSelected: (idx) => networkPage.ipv6Method = idx === 0 ? "auto" : idx === 1 ? "manual" : "ignore"
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.05) }

                    // DNS Section
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 12
                        Text { text: "DNS Configuration"; color: Theme.text; font.bold: true; font.pixelSize: 14 }
                        
                        Rectangle {
                            Layout.fillWidth: true; height: 36; radius: 8
                            color: Qt.rgba(0,0,0,0.2); border.color: dnsInput.activeFocus ? Theme.primary : "transparent"; border.width: 1
                            TextInput { 
                                id: dnsInput; anchors.fill: parent; anchors.margins: 8; color: Theme.text; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                                Text { text: "Otomatik (Boş Bırakın)"; visible: parent.text === "" && !parent.activeFocus; color: Theme.overlay; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Footer Actions
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Item { Layout.fillWidth: true }
                    
                    Rectangle {
                        width: 80; height: 36; radius: 8
                        color: Qt.rgba(255,255,255,0.1)
                        Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.text }
                        MouseArea { anchors.fill: parent; onClicked: editConnPopup.close(); cursorShape: Qt.PointingHandCursor }
                    }

                    Rectangle {
                        width: 80; height: 36; radius: 8
                        color: Theme.primary
                        Text { anchors.centerIn: parent; text: "Save"; color: "#1e1e2e"; font.bold: true }
                        MouseArea { 
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor 
                            onClicked: {
                                // Logic to save settings
                                var cmd = ["nmcli", "connection", "modify", networkPage.connName];
                                
                                // IPv4
                                if (networkPage.ipv4Method === "manual") {
                                    cmd.push("ipv4.method", "manual");
                                    // Append /24 if no prefix
                                    var ip = ipv4AddrInput.text;
                                    if (ip.indexOf("/") === -1) ip += "/24";
                                    cmd.push("ipv4.addresses", ip);
                                    
                                    if (ipv4GwInput.text) cmd.push("ipv4.gateway", ipv4GwInput.text);
                                    else cmd.push("ipv4.gateway", ""); // Clear gateway if empty
                                } else {
                                    cmd.push("ipv4.method", "auto");
                                }

                                // IPV6
                                if (networkPage.ipv6Method === "ignore") cmd.push("ipv6.method", "ignore");
                                else if (networkPage.ipv6Method === "manual") cmd.push("ipv6.method", "manual");
                                else cmd.push("ipv6.method", "auto");

                                // DNS
                                var dnsText = dnsInput.text.trim();
                                if (dnsText && dnsText.toLowerCase() !== "otomatik" && dnsText.toLowerCase() !== "automatic" && dnsText.toLowerCase() !== "auto") {
                                    cmd.push("ipv4.dns", dnsText.replace(/ /g, ","));
                                    cmd.push("ipv4.ignore-auto-dns", "yes");
                                } else {
                                    cmd.push("ipv4.dns", ""); // Clear DNS to use Auto
                                    cmd.push("ipv4.ignore-auto-dns", "no");
                                }

                                networkPage.applyStatus = "Applying...";
                                applyProc.errBuf = "";
                                applyProc.command = cmd;
                                applyProc.running = false;
                                applyProc.running = true;
                                // editConnPopup.close(); // Keep open to show status
                            }
                        }
                    }
                }
                
                // Status Text
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: networkPage.applyStatus
                    visible: networkPage.applyStatus !== ""
                    color: networkPage.applyError ? "#f38ba8" : "#a6e3a1"
                    font.bold: true
                    wrapMode: Text.Wrap
                }

                // Auto-close on success
                Timer {
                    interval: 1500; repeat: false; running: networkPage.applyStatus.indexOf("✅") !== -1
                    onTriggered: { editConnPopup.close(); networkPage.applyStatus = ""; }
                }
            }
        }
    }

    // ── Add VPN Popup ──

    // ═══════════ SEGMENT BUTTON COMPONENT ═══════════
    component SegmentButton: Row {
        property var options: []
        property int selectedIndex: 0
        signal selected(int idx)
        spacing: 0

        Repeater {
            model: options
            Rectangle {
                required property string modelData
                required property int index
                width: Math.max(segText.implicitWidth + 20, 70)
                height: 30
                radius: 6
                color: index === selectedIndex ? Theme.primary : Qt.rgba(49/255, 50/255, 68/255, 0.6)
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: segText
                    anchors.centerIn: parent
                    text: modelData
                    color: index === selectedIndex ? "#1e1e2e" : Theme.text
                    font.pixelSize: 11; font.bold: index === selectedIndex
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: selected(index)
                }
            }
        }
    }
}
