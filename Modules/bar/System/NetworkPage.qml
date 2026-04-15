import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette

Item {
    id: networkPage
    NetworkService {
        id: networkService
        active: networkPage.visible
    }

    property alias ifaceName: networkService.ifaceName
    property alias ipAddr: networkService.ipAddr
    property alias gateway: networkService.gateway
    property alias connName: networkService.connName
    property alias connStatus: networkService.connStatus
    property alias macAddr: networkService.macAddr
    property alias dns: networkService.dns
    property alias connType: networkService.connType
    property alias ipv4Method: networkService.ipv4Method
    property alias ipv6Method: networkService.ipv6Method
    property alias dnsMethod: networkService.dnsMethod
    property alias proxyMethod: networkService.proxyMethod
    property alias mtuValue: networkService.mtuValue
    property alias macMode: networkService.macMode
    property alias wifiList: networkService.wifiList
    property alias connectingSsid: networkService.connectingSsid
    property alias applyStatus: networkService.applyStatus
    property alias applyError: networkService.applyError

    function refresh() {
        networkService.refresh();
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
                color: SettingsPalette.surface
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
                        Text { text: connType === "wifi" ? "WiFi" : "Ethernet"; font.bold: true; font.pixelSize: 16; color: SettingsPalette.text }
                    }

                    // Info line
                    Rectangle {
                        Layout.fillWidth: true; height: 36
                        color: Qt.rgba(49/255, 50/255, 68/255, 0.4); radius: 8
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 12
                            Text { text: "Interface:"; color: SettingsPalette.subtext; font.pixelSize: 12 }
                            Text { text: networkPage.ifaceName || "—"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font" }
                            Text { text: "IP:"; color: SettingsPalette.subtext; font.pixelSize: 12 }
                            Text { text: networkPage.ipAddr || "—"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font" }
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
                                onClicked: {
                                    if (networkPage.ifaceName) {
                                        networkService.disconnectCurrentDevice();
                                    }
                                }
                            }
                        }
                    }
                }
            }



            // ═══════════ 3. DNS CONFIGURATION ═══════════
            Rectangle {
                Layout.fillWidth: true
                height: dnsCol.height + 28
                color: SettingsPalette.surface
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
                        Text { text: "DNS Configuration"; font.bold: true; font.pixelSize: 16; color: SettingsPalette.text }
                    }

                    RowLayout {
                        spacing: 10
                        Text { text: "DNS Method:"; color: SettingsPalette.subtext; font.pixelSize: 12 }
                        NetworkSegmentButton {
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
                color: SettingsPalette.surface
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
                        Text { text: "IP Configuration"; font.bold: true; font.pixelSize: 16; color: SettingsPalette.text }
                    }

                    // IPv4
                    Text { text: "IPv4"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 13 }
                    RowLayout {
                        spacing: 10
                        Text { text: "Method:"; color: SettingsPalette.subtext; font.pixelSize: 12 }
                        NetworkSegmentButton {
                            options: ["Automatic", "Manual", "Link-Local"]
                            selectedIndex: networkPage.ipv4Method === "auto" ? 0 : networkPage.ipv4Method === "manual" ? 1 : 2
                            onSelected: (idx) => {
                                networkPage.ipv4Method = idx === 0 ? "auto" : idx === 1 ? "manual" : "link-local";
                            }
                        }
                    }

                    // IPv6
                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.04) }
                    Text { text: "IPv6"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 13 }
                    RowLayout {
                        spacing: 10
                        Text { text: "Method:"; color: SettingsPalette.subtext; font.pixelSize: 12 }
                        NetworkSegmentButton {
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
                color: SettingsPalette.surface
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
                        Text { text: "Proxy Configuration"; font.bold: true; font.pixelSize: 16; color: SettingsPalette.text }
                    }

                    RowLayout {
                        spacing: 10
                        Text { text: "Proxy Method:"; color: SettingsPalette.subtext; font.pixelSize: 12 }
                        NetworkSegmentButton {
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
                color: SettingsPalette.surface
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
                        Text { text: "Advanced Settings"; font.bold: true; font.pixelSize: 16; color: SettingsPalette.text }
                    }

                    // MTU
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12

                        Text { text: "MTU:"; color: SettingsPalette.subtext; font.pixelSize: 12 }

                        Rectangle {
                            width: 100; height: 36; radius: 8
                            color: Qt.rgba(49/255, 50/255, 68/255, 0.6)
                            border.color: mtuInput.activeFocus ? Theme.primary : "transparent"
                            border.width: mtuInput.activeFocus ? 2 : 0

                            TextInput {
                                id: mtuInput
                                anchors.fill: parent; anchors.margins: 8
                                text: networkPage.mtuValue
                                color: SettingsPalette.text; font.pixelSize: 13
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                onTextChanged: networkPage.mtuValue = text
                            }
                        }

                        Text { text: "(576-9000, default: 1500)"; color: SettingsPalette.overlay; font.pixelSize: 11 }
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
                                        networkService.applyMtu();
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.04) }

                    // MAC Address
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12

                        Text { text: "MAC Address:"; color: SettingsPalette.subtext; font.pixelSize: 12 }

                        NetworkSegmentButton {
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
                                        networkService.applyMacMode();
                                    }
                                }
                            }
                        }
                    }

                    // Show current MAC
                    Text {
                        text: "Current: " + (networkPage.macAddr || "—")
                        color: SettingsPalette.overlay; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }



            // ═══════════ 7. WIFI LIST ═══════════
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.06) }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Available Networks"; color: SettingsPalette.subtext; font.pixelSize: 12; font.bold: true }
                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 24; height: 24; radius: 6
                    color: refreshMa.containsMouse ? SettingsPalette.surface : "transparent"
                    Text { anchors.centerIn: parent; text: "󰑐"; font.family: "JetBrainsMono Nerd Font"; color: SettingsPalette.subtext; font.pixelSize: 14 }
                    MouseArea {
                        id: refreshMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            networkService.refreshWifiScan();
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
                            color: modelData.active ? Theme.primary : SettingsPalette.text
                        }
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: modelData.ssid; color: modelData.active ? Theme.primary : SettingsPalette.text
                                font.bold: modelData.active; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                text: (modelData.security !== "" ? "🔒 " + modelData.security : "Açık") + " • " + modelData.signal + "%"
                                color: SettingsPalette.subtext; font.pixelSize: 10
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: modelData.bars; color: modelData.active ? Theme.primary : SettingsPalette.subtext; font.family: "DejaVu Sans" }
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
                            color: networkPage.connectingSsid === modelData.ssid ? SettingsPalette.surface
                                 : wifiConnMA.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

                            Text {
                                anchors.centerIn: parent
                                text: networkPage.connectingSsid === modelData.ssid ? "Bağlanıyor..." : "Bağlan"
                                color: networkPage.connectingSsid === modelData.ssid ? SettingsPalette.subtext : "#1e1e2e"
                                font.bold: true; font.pixelSize: 12
                            }
                            MouseArea {
                                id: wifiConnMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: networkPage.connectingSsid === ""
                                onClicked: {
                                    networkPage.connectingSsid = modelData.ssid;
                                    networkService.connectToWifi(modelData.ssid);
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
                    Text { text: "Edit Connection"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 16 }
                    Item { Layout.fillWidth: true }
                    Text { text: "✕"; color: SettingsPalette.subtext; font.pixelSize: 16; MouseArea { anchors.fill: parent; onClicked: editConnPopup.close(); cursorShape: Qt.PointingHandCursor } }
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
                            color: SettingsPalette.subtext; font.italic: true
                            readOnly: true
                            verticalAlignment: TextInput.AlignVCenter
                        }
                    }

                    // IPv4 Section
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 12
                        Text { text: "IPv4 Configuration"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 14 }
                        
                        RowLayout {
                            spacing: 12
                            Text { text: "Method:"; color: SettingsPalette.subtext; Layout.preferredWidth: 80 }
                            NetworkSegmentButton {
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
                                Text { text: "IP Address:"; color: SettingsPalette.subtext; Layout.preferredWidth: 80 }
                                Rectangle {
                                    Layout.fillWidth: true; height: 36; radius: 8
                                    color: Qt.rgba(0,0,0,0.2); border.color: ipv4AddrInput.activeFocus ? Theme.primary : "transparent"; border.width: 1
                                    TextInput { id: ipv4AddrInput; anchors.fill: parent; anchors.margins: 8; color: SettingsPalette.text; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Gateway:"; color: SettingsPalette.subtext; Layout.preferredWidth: 80 }
                                Rectangle {
                                    Layout.fillWidth: true; height: 36; radius: 8
                                    color: Qt.rgba(0,0,0,0.2); border.color: ipv4GwInput.activeFocus ? Theme.primary : "transparent"; border.width: 1
                                    TextInput { id: ipv4GwInput; anchors.fill: parent; anchors.margins: 8; color: SettingsPalette.text; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.05) }

                    // IPv6 Section (Simplified)
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 12
                        Text { text: "IPv6 Configuration"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 14 }
                        
                        RowLayout {
                            spacing: 12
                            Text { text: "Method:"; color: SettingsPalette.subtext; Layout.preferredWidth: 80 }
                            NetworkSegmentButton {
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
                        Text { text: "DNS Configuration"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 14 }
                        
                        Rectangle {
                            Layout.fillWidth: true; height: 36; radius: 8
                            color: Qt.rgba(0,0,0,0.2); border.color: dnsInput.activeFocus ? Theme.primary : "transparent"; border.width: 1
                            TextInput { 
                                id: dnsInput; anchors.fill: parent; anchors.margins: 8; color: SettingsPalette.text; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                                Text { text: "Otomatik (Boş Bırakın)"; visible: parent.text === "" && !parent.activeFocus; color: SettingsPalette.overlay; anchors.verticalCenter: parent.verticalCenter }
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
                        Text { anchors.centerIn: parent; text: "Cancel"; color: SettingsPalette.text }
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

                                networkService.applyConnectionSettings(cmd);
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

}
