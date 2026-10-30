import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../../Widgets"
import "../../../Services" as S

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
                border.color: Theme.withAlpha(Theme.text, 0.04)
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
                        Text {  text: connType === "wifi" ? "WiFi" : "Ethernet"; font.bold: true; font.pixelSize: 16; color: SettingsPalette.text; font.family: Theme.fontFamily }
                    }

                    // Info line
                    Rectangle {
                        Layout.fillWidth: true; height: 36
                        color: Theme.withAlpha(Theme.surface, 0.4); radius: 8
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 12
                            Text {  text: "Interface:"; color: SettingsPalette.subtext; font.pixelSize: 12; font.family: Theme.fontFamily }
                            Text { text: networkPage.ifaceName || "—"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 12; font.family: Theme.fontFamily }
                            Text {  text: "IP:"; color: SettingsPalette.subtext; font.pixelSize: 12; font.family: Theme.fontFamily }
                            Text { text: networkPage.ipAddr || "—"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 12; font.family: Theme.fontFamily }
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
                            Text {  anchors.centerIn: parent; text: "Edit"; color: Theme.foregroundFor(Theme.primary); font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                            MouseArea {
                                id: editMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { editConnPopup.open(); }
                            }
                        }

                        Rectangle {
                            width: 90; height: 32; radius: 8
                            color: discMA.containsMouse ? Qt.lighter(Theme.cpRed, 1.15) : Theme.withAlpha(Theme.red, 0.2)
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {  anchors.centerIn: parent; text: "Disconnect"; color: Theme.cpRed; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
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
                border.color: Theme.withAlpha(Theme.text, 0.04)
                border.width: 1

                ColumnLayout {
                    id: dnsCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        spacing: 8
                        Text { text: "󰇧"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"; color: Theme.cpMauve }
                        Text {  text: "DNS Configuration"; font.bold: true; font.pixelSize: 16; color: SettingsPalette.text; font.family: Theme.fontFamily }
                    }

                    RowLayout {
                        spacing: 10
                        Text {  text: "DNS Method:"; color: SettingsPalette.subtext; font.pixelSize: 12; font.family: Theme.fontFamily }
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
                border.color: Theme.withAlpha(Theme.text, 0.04)
                border.width: 1

                ColumnLayout {
                    id: ipCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 14
                    spacing: 14

                    RowLayout {
                        spacing: 8
                        Text { text: ""; font.pixelSize: 16; font.family: Theme.fontFamily; color: Theme.cpPeach }
                        Text {  text: "IP Configuration"; font.bold: true; font.pixelSize: 16; color: SettingsPalette.text; font.family: Theme.fontFamily }
                    }

                    // IPv4
                    Text {  text: "IPv4"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 13; font.family: Theme.fontFamily }
                    RowLayout {
                        spacing: 10
                        Text {  text: "Method:"; color: SettingsPalette.subtext; font.pixelSize: 12; font.family: Theme.fontFamily }
                        NetworkSegmentButton {
                            options: ["Automatic", "Manual", "Link-Local"]
                            selectedIndex: networkPage.ipv4Method === "auto" ? 0 : networkPage.ipv4Method === "manual" ? 1 : 2
                            onSelected: (idx) => {
                                networkPage.ipv4Method = idx === 0 ? "auto" : idx === 1 ? "manual" : "link-local";
                            }
                        }
                    }

                    // IPv6
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.withAlpha(Theme.text, 0.04) }
                    Text {  text: "IPv6"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 13; font.family: Theme.fontFamily }
                    RowLayout {
                        spacing: 10
                        Text {  text: "Method:"; color: SettingsPalette.subtext; font.pixelSize: 12; font.family: Theme.fontFamily }
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
                border.color: Theme.withAlpha(Theme.text, 0.04)
                border.width: 1

                ColumnLayout {
                    id: proxyCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        spacing: 8
                        Text { text: ""; font.pixelSize: 16; font.family: Theme.fontFamily; color: Theme.cpBlue }
                        Text {  text: "Proxy Configuration"; font.bold: true; font.pixelSize: 16; color: SettingsPalette.text; font.family: Theme.fontFamily }
                    }

                    RowLayout {
                        spacing: 10
                        Text {  text: "Proxy Method:"; color: SettingsPalette.subtext; font.pixelSize: 12; font.family: Theme.fontFamily }
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
                border.color: Theme.withAlpha(Theme.text, 0.04)
                border.width: 1

                ColumnLayout {
                    id: advancedCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 14
                    spacing: 14

                    RowLayout {
                        spacing: 8
                        Text { text: ""; font.pixelSize: 16; font.family: Theme.fontFamily; color: Theme.cpPink }
                        Text {  text: "Advanced Settings"; font.bold: true; font.pixelSize: 16; color: SettingsPalette.text; font.family: Theme.fontFamily }
                    }

                    // MTU
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12

                        Text {  text: "MTU:"; color: SettingsPalette.subtext; font.pixelSize: 12; font.family: Theme.fontFamily }

                        Rectangle {
                            width: 100; height: 36; radius: 8
                            color: Theme.withAlpha(Theme.surface, 0.6)
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

                        Text {  text: "(576-9000, default: 1500)"; color: SettingsPalette.overlay; font.pixelSize: 11; font.family: Theme.fontFamily }
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 60; height: 30; radius: 8
                            color: mtuApplyMA.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {  anchors.centerIn: parent; text: "Apply"; color: Theme.foregroundFor(Theme.primary); font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily }
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

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.withAlpha(Theme.text, 0.04) }

                    // MAC Address
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12

                        Text {  text: "MAC Address:"; color: SettingsPalette.subtext; font.pixelSize: 12; font.family: Theme.fontFamily }

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
                            Text {  anchors.centerIn: parent; text: "Apply"; color: Theme.foregroundFor(Theme.primary); font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily }
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
                        color: SettingsPalette.overlay; font.pixelSize: 11; font.family: Theme.fontFamily
                    }
                }
            }



            // ═══════════ 7. VPN ═══════════
            Rectangle {
                id: vpnCard
                Layout.fillWidth: true
                height: vpnCol.height + 28
                color: SettingsPalette.surface
                radius: 12
                border.color: S.VpnService.connected ? Theme.withAlpha(Theme.green, 0.25) : Theme.withAlpha(Theme.text, 0.04)
                border.width: 1

                // UUID whose "Remove" was clicked once and now waits for confirmation.
                property string confirmDeleteUuid: ""
                Timer { id: confirmDeleteTimer; interval: 4000; onTriggered: vpnCard.confirmDeleteUuid = "" }

                ColumnLayout {
                    id: vpnCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "󰦝"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"; color: Theme.cpGreen }
                        Text { text: "VPN"; font.bold: true; font.pixelSize: 16; color: SettingsPalette.text; font.family: Theme.fontFamily }

                        // Connection status pill
                        Rectangle {
                            implicitWidth: vpnStatusRow.implicitWidth + 16; height: 24; radius: 12
                            color: S.VpnService.connected ? Theme.withAlpha(Theme.green, 0.15) : Theme.withAlpha(Theme.text, 0.05)
                            RowLayout {
                                id: vpnStatusRow
                                anchors.centerIn: parent
                                spacing: 6
                                Rectangle { width: 7; height: 7; radius: 4; color: S.VpnService.connected ? SettingsPalette.readableAccent(Theme.green) : SettingsPalette.overlay2 }
                                Text {
                                    text: S.VpnService.connected
                                        ? (S.VpnService.activeNames.length > 1 ? S.VpnService.activeNames.length + " connected" : S.VpnService.activeName)
                                        : "Not connected"
                                    font.pixelSize: 11; font.family: Theme.fontFamily
                                    color: S.VpnService.connected ? SettingsPalette.readableAccent(Theme.green) : SettingsPalette.subtext
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: addVpnLabel.implicitWidth + 24; height: 32; radius: 8
                            color: addVpnMA.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { id: addVpnLabel; anchors.centerIn: parent; text: "+ Add VPN"; color: Theme.foregroundFor(Theme.primary); font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                            MouseArea {
                                id: addVpnMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: addVpnPopup.open()
                            }
                        }
                    }

                    // Error banner (dismissable)
                    Rectangle {
                        visible: S.VpnService.errorMessage.length > 0
                        Layout.fillWidth: true
                        implicitHeight: vpnErrorRow.implicitHeight + 16
                        radius: 8
                        color: Theme.withAlpha(Theme.red, 0.12)
                        border.color: Theme.withAlpha(Theme.red, 0.35); border.width: 1
                        RowLayout {
                            id: vpnErrorRow
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            spacing: 8
                            Text {
                                Layout.fillWidth: true
                                text: "⚠ " + S.VpnService.errorMessage
                                wrapMode: Text.WordWrap
                                color: SettingsPalette.readableAccent(Theme.red); font.pixelSize: 12; font.family: Theme.fontFamily
                            }
                            Text {
                                text: "✕"; color: SettingsPalette.readableAccent(Theme.red); font.pixelSize: 13
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: S.VpnService.clearError() }
                            }
                        }
                    }

                    Text {
                        visible: S.VpnService.profiles.length === 0
                        Layout.fillWidth: true
                        text: "No VPN yet. Use “+ Add VPN” to import the WireGuard (.conf) or OpenVPN (.ovpn) file from your VPN provider."
                        color: SettingsPalette.subtext; font.pixelSize: 12; font.family: Theme.fontFamily
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: S.VpnService.profiles

                        Rectangle {
                            id: vpnRow
                            required property var modelData
                            readonly property string uuid: modelData.uuid
                            readonly property string vpnState: S.VpnService.stateOf(uuid)
                            readonly property bool active: vpnState === "activated"
                            readonly property bool transitioning: vpnState === "activating" || vpnState === "deactivating"
                            readonly property bool rowBusy: S.VpnService.busyUuid === uuid || S.VpnService.busyUuid === "*" || transitioning
                            readonly property bool confirming: vpnCard.confirmDeleteUuid === uuid
                            property string duration: ""

                            function refreshDuration() {
                                duration = active ? S.VpnService.getConnectionDuration(uuid) : "";
                            }
                            onActiveChanged: refreshDuration()
                            Component.onCompleted: refreshDuration()
                            Connections {
                                target: S.VpnService
                                enabled: vpnRow.active
                                function onConnectionInfoUpdated() { vpnRow.refreshDuration(); }
                            }

                            Layout.fillWidth: true
                            height: 58; radius: 10
                            color: active ? Theme.withAlpha(Theme.green, 0.08) : Theme.withAlpha(Theme.text, 0.03)
                            border.color: active ? Theme.withAlpha(Theme.green, 0.3) : (transitioning ? Theme.withAlpha(Theme.yellow, 0.35) : "transparent")
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10
                                spacing: 10
                                Text {
                                    text: vpnRow.modelData.type === "wireguard" ? "󰖂" : "󰦝"
                                    font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"
                                    color: vpnRow.active ? SettingsPalette.readableAccent(Theme.green) : SettingsPalette.subtext
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: vpnRow.modelData.name
                                        elide: Text.ElideRight
                                        color: SettingsPalette.text; font.pixelSize: 13; font.bold: vpnRow.active; font.family: Theme.fontFamily
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: {
                                            var kind = vpnRow.modelData.type === "wireguard" ? "WireGuard" : "OpenVPN";
                                            if (vpnRow.vpnState === "activating") return kind + " • Connecting…";
                                            if (vpnRow.vpnState === "deactivating") return kind + " • Disconnecting…";
                                            if (vpnRow.active) return kind + " • Connected" + (vpnRow.duration ? " for " + vpnRow.duration : "");
                                            return kind;
                                        }
                                        color: vpnRow.active ? SettingsPalette.readableAccent(Theme.green) : SettingsPalette.subtext
                                        font.pixelSize: 11; font.family: Theme.fontFamily
                                    }
                                }

                                // Autoconnect switch
                                RowLayout {
                                    spacing: 6
                                    Text { text: "Auto"; color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.fontFamily }
                                    Rectangle {
                                        width: 34; height: 18; radius: 9
                                        color: vpnRow.modelData.autoconnect ? SettingsPalette.readableAccent(Theme.primary) : Theme.withAlpha(Theme.text, 0.12)
                                        opacity: S.VpnService.isBusy ? 0.5 : 1
                                        Rectangle {
                                            width: 14; height: 14; radius: 7
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: vpnRow.modelData.autoconnect ? parent.width - width - 2 : 2
                                            color: vpnRow.modelData.autoconnect ? SettingsPalette.foregroundFor(SettingsPalette.readableAccent(Theme.primary)) : SettingsPalette.text
                                            Behavior on x { NumberAnimation { duration: 120 } }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: if (!S.VpnService.isBusy) S.VpnService.setAutoconnect(vpnRow.uuid, !vpnRow.modelData.autoconnect)
                                        }
                                    }
                                }

                                // Connect / Disconnect
                                Rectangle {
                                    width: 100; height: 30; radius: 8
                                    color: vpnRow.rowBusy || (S.VpnService.isBusy && !vpnRow.rowBusy) ? Theme.withAlpha(Theme.text, 0.06)
                                         : vpnRow.active ? (vpnToggleMA.containsMouse ? Theme.withAlpha(Theme.red, 0.3) : Theme.withAlpha(Theme.red, 0.2))
                                         : (vpnToggleMA.containsMouse ? Theme.withAlpha(Theme.green, 0.3) : Theme.withAlpha(Theme.green, 0.18))
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: vpnRow.vpnState === "activating" ? "Connecting…"
                                            : vpnRow.vpnState === "deactivating" ? "Stopping…"
                                            : vpnRow.rowBusy ? "Please wait…"
                                            : (vpnRow.active ? "Disconnect" : "Connect")
                                        color: vpnRow.rowBusy ? SettingsPalette.subtext : (vpnRow.active ? Theme.cpRed : SettingsPalette.readableAccent(Theme.green))
                                        font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily
                                    }
                                    MouseArea {
                                        id: vpnToggleMA; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: S.VpnService.isBusy ? Qt.BusyCursor : Qt.PointingHandCursor
                                        onClicked: {
                                            if (S.VpnService.isBusy) return;
                                            // A stuck "activating" profile can still be stopped.
                                            if (vpnRow.active || vpnRow.vpnState === "activating") S.VpnService.disconnect(vpnRow.uuid);
                                            else S.VpnService.connect(vpnRow.uuid);
                                        }
                                    }
                                }

                                // Remove (two-step)
                                Rectangle {
                                    width: vpnRow.confirming ? 76 : 30; height: 30; radius: 8
                                    color: vpnRow.confirming ? Theme.withAlpha(Theme.red, 0.3)
                                         : (removeMA.containsMouse ? Theme.withAlpha(Theme.red, 0.15) : "transparent")
                                    Behavior on width { NumberAnimation { duration: 120 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: vpnRow.confirming ? "Confirm" : "󰆴"
                                        font.family: vpnRow.confirming ? Theme.fontFamily : "JetBrainsMono Nerd Font"
                                        font.pixelSize: vpnRow.confirming ? 12 : 15; font.bold: vpnRow.confirming
                                        color: removeMA.containsMouse || vpnRow.confirming ? Theme.cpRed : SettingsPalette.subtext
                                    }
                                    MouseArea {
                                        id: removeMA; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: S.VpnService.isBusy ? Qt.BusyCursor : Qt.PointingHandCursor
                                        onClicked: {
                                            if (S.VpnService.isBusy) return;
                                            if (vpnRow.confirming) {
                                                vpnCard.confirmDeleteUuid = "";
                                                S.VpnService.deleteConnection(vpnRow.uuid);
                                            } else {
                                                vpnCard.confirmDeleteUuid = vpnRow.uuid;
                                                confirmDeleteTimer.restart();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: S.VpnService.activeUuids.length > 1
                        Layout.alignment: Qt.AlignRight
                        width: 130; height: 30; radius: 8
                        color: discAllMA.containsMouse ? Theme.withAlpha(Theme.red, 0.3) : Theme.withAlpha(Theme.red, 0.2)
                        Text { anchors.centerIn: parent; text: "Disconnect All"; color: Theme.cpRed; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                        MouseArea {
                            id: discAllMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: if (!S.VpnService.isBusy) S.VpnService.disconnectAllActive()
                        }
                    }
                }
            }

            // ═══════════ 7b. SITES WITHOUT VPN ═══════════
            Rectangle {
                id: bypassCard
                Layout.fillWidth: true
                height: bypassCol.height + 28
                color: SettingsPalette.surface
                radius: 12
                border.color: Theme.withAlpha(Theme.text, 0.04)
                border.width: 1

                property bool showLegacy: false

                function submit() {
                    var text = bypassInput.text.trim();
                    if (!text.length || S.VpnBypassService.busy) return;
                    S.VpnBypassService.addSite(text);
                    bypassInput.text = "";
                }

                Component.onCompleted: S.VpnBypassService.status()

                ColumnLayout {
                    id: bypassCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "󰖟"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"; color: Theme.cpBlue }
                        Text { text: "Sites Without VPN"; font.bold: true; font.pixelSize: 16; color: SettingsPalette.text; font.family: Theme.fontFamily }
                        Rectangle {
                            visible: S.VpnBypassService.sites.length > 0
                            implicitWidth: bypassCount.implicitWidth + 14; height: 22; radius: 11
                            color: Theme.withAlpha(Theme.text, 0.06)
                            Text { id: bypassCount; anchors.centerIn: parent; text: S.VpnBypassService.sites.length; color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.fontFamily }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            visible: S.VpnBypassService.sites.length > 0
                            width: refreshBypassLabel.implicitWidth + 20; height: 28; radius: 8
                            color: refreshBypassMA.containsMouse ? Theme.withAlpha(Theme.text, 0.1) : Theme.withAlpha(Theme.text, 0.05)
                            Text {
                                id: refreshBypassLabel
                                anchors.centerIn: parent
                                text: S.VpnBypassService.busy ? "Working…" : "󰑐 Refresh"
                                color: SettingsPalette.text; font.pixelSize: 12; font.family: Theme.fontFamily
                            }
                            MouseArea {
                                id: refreshBypassMA; anchors.fill: parent; hoverEnabled: true
                                cursorShape: S.VpnBypassService.busy ? Qt.BusyCursor : Qt.PointingHandCursor
                                onClicked: if (!S.VpnBypassService.busy) S.VpnBypassService.refresh()
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: S.VpnBypassService.vpnActive
                              ? "These sites open over your normal connection instead of the VPN."
                              : "No VPN is connected now, so every site uses your normal connection. The list applies whenever a VPN is on."
                        color: SettingsPalette.subtext; font.pixelSize: 12; font.family: Theme.fontFamily
                    }

                    // Add a site
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36; radius: 8
                            color: Theme.withAlpha(Theme.text, 0.04)
                            border.width: 1
                            border.color: bypassInput.activeFocus ? SettingsPalette.readableAccent(Theme.primary) : Theme.withAlpha(Theme.text, 0.12)
                            TextInput {
                                id: bypassInput
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: SettingsPalette.text; font.pixelSize: 13; font.family: Theme.fontFamily
                                selectByMouse: true; clip: true
                                enabled: !S.VpnBypassService.busy
                                Keys.onReturnPressed: bypassCard.submit()
                                Keys.onEnterPressed: bypassCard.submit()
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.leftMargin: 12
                                visible: bypassInput.text.length === 0 && !bypassInput.activeFocus
                                text: "Add a site, e.g. example.com or a link"
                                color: SettingsPalette.overlay; font.pixelSize: 13; font.family: Theme.fontFamily
                            }
                        }
                        Rectangle {
                            readonly property bool ready: bypassInput.text.trim().length > 0 && !S.VpnBypassService.busy
                            width: 80; height: 36; radius: 8
                            color: ready ? (addBypassMA.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary) : Theme.withAlpha(Theme.text, 0.08)
                            Text {
                                anchors.centerIn: parent
                                text: S.VpnBypassService.busy ? "…" : "Add"
                                color: parent.ready ? Theme.foregroundFor(Theme.primary) : SettingsPalette.overlay
                                font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily
                            }
                            MouseArea {
                                id: addBypassMA; anchors.fill: parent; hoverEnabled: true
                                cursorShape: parent.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: bypassCard.submit()
                            }
                        }
                    }

                    // Error
                    Rectangle {
                        visible: S.VpnBypassService.errorMessage.length > 0
                        Layout.fillWidth: true
                        implicitHeight: bypassErrorRow.implicitHeight + 14
                        radius: 8
                        color: Theme.withAlpha(Theme.red, 0.12)
                        border.color: Theme.withAlpha(Theme.red, 0.35); border.width: 1
                        RowLayout {
                            id: bypassErrorRow
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            Text {
                                Layout.fillWidth: true
                                text: "⚠ " + S.VpnBypassService.errorMessage
                                wrapMode: Text.WordWrap
                                color: SettingsPalette.readableAccent(Theme.red); font.pixelSize: 12; font.family: Theme.fontFamily
                            }
                            Text {
                                text: "✕"; color: SettingsPalette.readableAccent(Theme.red); font.pixelSize: 13
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: S.VpnBypassService.clearError() }
                            }
                        }
                    }

                    Text {
                        visible: S.VpnBypassService.loaded && S.VpnBypassService.sites.length === 0
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "No sites yet. Added sites skip the VPN, for example a bank or a service that blocks VPNs."
                        color: SettingsPalette.overlay; font.pixelSize: 12; font.family: Theme.fontFamily
                    }

                    // Site list
                    Repeater {
                        model: S.VpnBypassService.sites
                        Rectangle {
                            id: siteRow
                            required property var modelData
                            Layout.fillWidth: true
                            height: 46; radius: 8
                            color: Theme.withAlpha(Theme.text, 0.03)
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8
                                spacing: 10
                                Text {
                                    text: !S.VpnBypassService.vpnActive ? "󰖟" : (siteRow.modelData.direct ? "󰄬" : "󰀦")
                                    font.pixelSize: 15; font.family: "JetBrainsMono Nerd Font"
                                    color: !S.VpnBypassService.vpnActive ? SettingsPalette.subtext
                                         : siteRow.modelData.direct ? SettingsPalette.readableAccent(Theme.green) : SettingsPalette.readableAccent(Theme.yellow)
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        Layout.fillWidth: true
                                        text: siteRow.modelData.domain; elide: Text.ElideRight
                                        color: SettingsPalette.text; font.pixelSize: 13; font.family: Theme.fontFamily
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: {
                                            var n = siteRow.modelData.ipv4.length;
                                            var count = n + (n === 1 ? " address" : " addresses");
                                            if (!S.VpnBypassService.vpnActive) return count;
                                            return (siteRow.modelData.direct ? "Opens without VPN" : "Not applied yet, press Refresh") + " • " + count;
                                        }
                                        color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.fontFamily
                                    }
                                }
                                Rectangle {
                                    width: 76; height: 28; radius: 8
                                    color: removeSiteMA.containsMouse ? Theme.withAlpha(Theme.red, 0.25) : Theme.withAlpha(Theme.red, 0.12)
                                    opacity: S.VpnBypassService.busy ? 0.5 : 1
                                    Text { anchors.centerIn: parent; text: "Remove"; color: Theme.cpRed; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                                    MouseArea {
                                        id: removeSiteMA; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: S.VpnBypassService.busy ? Qt.BusyCursor : Qt.PointingHandCursor
                                        onClicked: if (!S.VpnBypassService.busy) S.VpnBypassService.removeSite(siteRow.modelData.domain)
                                    }
                                }
                            }
                        }
                    }

                    // Addresses bypassed before this list existed
                    Rectangle {
                        visible: S.VpnBypassService.legacy.length > 0
                        Layout.fillWidth: true
                        height: 40; radius: 8
                        color: legacyMA.containsMouse ? Theme.withAlpha(Theme.text, 0.06) : Theme.withAlpha(Theme.text, 0.03)
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                            Text {
                                text: bypassCard.showLegacy ? "▾" : "▸"
                                color: SettingsPalette.subtext; font.pixelSize: 12
                            }
                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: S.VpnBypassService.legacy.length + " addresses added earlier • site names unknown"
                                color: SettingsPalette.text; font.pixelSize: 12; font.family: Theme.fontFamily
                            }
                        }
                        MouseArea {
                            id: legacyMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: bypassCard.showLegacy = !bypassCard.showLegacy
                        }
                    }

                    Flow {
                        visible: bypassCard.showLegacy && S.VpnBypassService.legacy.length > 0
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: bypassCard.showLegacy ? S.VpnBypassService.legacy : []
                            Rectangle {
                                id: legacyChip
                                required property var modelData
                                width: legacyChipRow.implicitWidth + 16; height: 26; radius: 13
                                color: Theme.withAlpha(Theme.text, 0.05)
                                RowLayout {
                                    id: legacyChipRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: legacyChip.modelData; color: SettingsPalette.text; font.pixelSize: 11; font.family: Theme.fontFamily }
                                    Text {
                                        text: "✕"; font.pixelSize: 11
                                        color: chipRemoveMA.containsMouse ? Theme.cpRed : SettingsPalette.subtext
                                        MouseArea {
                                            id: chipRemoveMA; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true
                                            cursorShape: S.VpnBypassService.busy ? Qt.BusyCursor : Qt.PointingHandCursor
                                            onClicked: if (!S.VpnBypassService.busy) S.VpnBypassService.removeLegacy(legacyChip.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ═══════════ 8. WIFI LIST ═══════════
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.withAlpha(Theme.text, 0.06) }

            RowLayout {
                Layout.fillWidth: true
                Text {  text: "Available Networks"; color: SettingsPalette.subtext; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
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
                    implicitHeight: wifiExpanded ? wifiActions.y + wifiActions.implicitHeight + 12 : 48
                    color: modelData.active ? Theme.withAlpha(Theme.primary, 0.15)
                         : (wifiHoverMa.containsMouse || wifiExpanded ? Theme.withAlpha(Theme.text, 0.05) : "transparent")
                    radius: 8; clip: true

                    property bool wifiExpanded: false
                    onWifiExpandedChanged: if (!wifiExpanded) wifiPassword.clear()

                    RowLayout {
                        id: wifiHeader
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        height: 48; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12

                        Text {
                            text: "󰖩"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"
                            color: modelData.active ? Theme.primary : SettingsPalette.text
                        }
                        ColumnLayout {
                            spacing: 2
                            Text {
                                font.family: Theme.fontFamily
                                text: modelData.ssid; color: modelData.active ? Theme.primary : SettingsPalette.text
                                font.bold: modelData.active; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                font.family: Theme.fontFamily
                                text: (modelData.security !== "" ? "🔒 " + modelData.security : "Open") + " • " + modelData.signal + "%"
                                color: SettingsPalette.subtext; font.pixelSize: 10
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Item {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 18
                            Layout.alignment: Qt.AlignVCenter

                            Row {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                spacing: 2

                                Repeater {
                                    model: 4
                                    Rectangle {
                                        required property int index
                                        width: 4
                                        height: 4 + index * 3
                                        y: parent.height - height
                                        radius: 1
                                        color: index < wifiDelegate.modelData.barLevel
                                            ? (wifiDelegate.modelData.active ? Theme.primary : SettingsPalette.subtext)
                                            : Theme.withAlpha(SettingsPalette.subtext, 0.18)
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: wifiHoverMa
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        height: 48; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (!modelData.active) wifiDelegate.wifiExpanded = !wifiDelegate.wifiExpanded; }
                    }

                    ColumnLayout {
                        id: wifiActions
                        anchors.left: parent.left
                        anchors.top: wifiHeader.bottom; anchors.topMargin: 8
                        anchors.leftMargin: 16
                        width: Math.max(0, Math.min(480, parent.width - 32))
                        spacing: 12; visible: wifiDelegate.wifiExpanded

                        Text {
                            Layout.fillWidth: true
                            text: "Wi-Fi password"
                            visible: wifiPassword.visible
                            color: SettingsPalette.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12; font.bold: true
                        }

                        TextField {
                            id: wifiPassword
                            Layout.fillWidth: true
                            visible: wifiDelegate.modelData.security !== "" && wifiDelegate.modelData.security !== "--"
                            enabled: networkPage.connectingSsid === ""
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText
                            implicitHeight: 40
                            leftPadding: 12; rightPadding: 12
                            topPadding: 10; bottomPadding: 10
                            font.pixelSize: 13
                            placeholderText: "Enter password"
                            Accessible.name: "Wi-Fi password"
                            color: SettingsPalette.text
                            placeholderTextColor: SettingsPalette.subtext
                            font.family: Theme.fontFamily
                            background: Rectangle { radius: 6; color: SettingsPalette.surface; border.color: wifiPassword.activeFocus ? Theme.primary : SettingsPalette.subtext }
                            onVisibleChanged: if (!visible) clear()
                            onAccepted: if (networkPage.connectingSsid === "") wifiConnMA.clicked(null)
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: wifiPassword.visible
                            text: "Leave blank to use the saved password."
                            color: SettingsPalette.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: networkService.wifiStatusSsid === wifiDelegate.modelData.ssid && networkService.wifiStatus !== ""
                            text: visible ? networkService.wifiStatus : ""
                            wrapMode: Text.Wrap
                            color: networkService.wifiError ? Theme.cpRed : SettingsPalette.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        Rectangle {
                            Layout.alignment: Qt.AlignRight
                            implicitWidth: 120; implicitHeight: 36; radius: 6
                            color: networkPage.connectingSsid === modelData.ssid ? SettingsPalette.surface
                                 : wifiConnMA.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

                            Text {
                                font.family: Theme.fontFamily
                                anchors.centerIn: parent
                                text: networkPage.connectingSsid === modelData.ssid ? "Connecting..." : "Connect"
                                color: networkPage.connectingSsid === modelData.ssid ? SettingsPalette.subtext : Theme.foregroundFor(Theme.primary)
                                font.bold: true; font.pixelSize: 12
                            }
                            MouseArea {
                                id: wifiConnMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: networkPage.connectingSsid === ""
                                onClicked: {
                                    networkService.connectToWifi(modelData.ssid, wifiPassword.text);
                                    wifiPassword.clear();
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
            color: Theme.background
            radius: 16
            border.color: Theme.withAlpha(Theme.text, 0.1)
            border.width: 1

            MouseArea { anchors.fill: parent } // Block clicks

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 24
                spacing: 20

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {  text: "Edit Connection"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 16; font.family: Theme.fontFamily }
                    Item { Layout.fillWidth: true }
                    Text { font.family: Theme.fontFamily; text: "✕"; color: SettingsPalette.subtext; font.pixelSize: 16; MouseArea { anchors.fill: parent; onClicked: editConnPopup.close(); cursorShape: Qt.PointingHandCursor } }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.withAlpha(Theme.text, 0.1) }
                
                // Content
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 20
                    
                    // Connection Name Display
                    Rectangle {
                        Layout.fillWidth: true; height: 40
                        color: Theme.withAlpha(Theme.text, 0.05); radius: 8
                        border.color: Theme.withAlpha(Theme.text, 0.1)
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
                        Text {  text: "IPv4 Configuration"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 14; font.family: Theme.fontFamily }
                        
                        RowLayout {
                            spacing: 12
                            Text {  text: "Method:"; color: SettingsPalette.subtext; Layout.preferredWidth: 80; font.family: Theme.fontFamily }
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
                                Text {  text: "IP Address:"; color: SettingsPalette.subtext; Layout.preferredWidth: 80; font.family: Theme.fontFamily }
                                Rectangle {
                                    Layout.fillWidth: true; height: 36; radius: 8
                                    color: Qt.rgba(0,0,0,0.2); border.color: ipv4AddrInput.activeFocus ? Theme.primary : "transparent"; border.width: 1
                                    TextInput { id: ipv4AddrInput; anchors.fill: parent; anchors.margins: 8; color: SettingsPalette.text; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {  text: "Gateway:"; color: SettingsPalette.subtext; Layout.preferredWidth: 80; font.family: Theme.fontFamily }
                                Rectangle {
                                    Layout.fillWidth: true; height: 36; radius: 8
                                    color: Qt.rgba(0,0,0,0.2); border.color: ipv4GwInput.activeFocus ? Theme.primary : "transparent"; border.width: 1
                                    TextInput { id: ipv4GwInput; anchors.fill: parent; anchors.margins: 8; color: SettingsPalette.text; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.withAlpha(Theme.text, 0.05) }

                    // IPv6 Section (Simplified)
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 12
                        Text {  text: "IPv6 Configuration"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 14; font.family: Theme.fontFamily }
                        
                        RowLayout {
                            spacing: 12
                            Text {  text: "Method:"; color: SettingsPalette.subtext; Layout.preferredWidth: 80; font.family: Theme.fontFamily }
                            NetworkSegmentButton {
                                options: ["Automatic", "Manual", "Ignore"]
                                selectedIndex: networkPage.ipv6Method === "auto" ? 0 : networkPage.ipv6Method === "manual" ? 1 : 2
                                onSelected: (idx) => networkPage.ipv6Method = idx === 0 ? "auto" : idx === 1 ? "manual" : "ignore"
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.withAlpha(Theme.text, 0.05) }

                    // DNS Section
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 12
                        Text {  text: "DNS Configuration"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 14; font.family: Theme.fontFamily }
                        
                        Rectangle {
                            Layout.fillWidth: true; height: 36; radius: 8
                            color: Qt.rgba(0,0,0,0.2); border.color: dnsInput.activeFocus ? Theme.primary : "transparent"; border.width: 1
                            TextInput { 
                                id: dnsInput; anchors.fill: parent; anchors.margins: 8; color: SettingsPalette.text; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                                Text {  text: "Automatic (leave empty)"; visible: parent.text === "" && !parent.activeFocus; color: SettingsPalette.overlay; anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontFamily }
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
                        color: Theme.withAlpha(Theme.text, 0.1)
                        Text {  anchors.centerIn: parent; text: "Cancel"; color: SettingsPalette.text; font.family: Theme.fontFamily }
                        MouseArea { anchors.fill: parent; onClicked: editConnPopup.close(); cursorShape: Qt.PointingHandCursor }
                    }

                    Rectangle {
                        width: 80; height: 36; radius: 8
                        color: Theme.primary
                        Text {  anchors.centerIn: parent; text: "Save"; color: Theme.foregroundFor(Theme.primary); font.bold: true; font.family: Theme.fontFamily }
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
                    font.family: Theme.fontFamily
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: networkPage.applyStatus
                    visible: networkPage.applyStatus !== ""
                    color: networkPage.applyError ? Theme.cpRed : Theme.cpGreen
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
    AddVpnPopup {
        id: addVpnPopup
        onSuccess: S.VpnService.refreshAll()
    }

}
