
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.platform
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette

Item {
    id: sysInfoPage
    SystemInfoService { id: sysInfoService }

    property alias hostname: sysInfoService.hostname
    property alias username: sysInfoService.username
    property alias distro: sysInfoService.distro
    property alias kernel: sysInfoService.kernel
    property alias uptime: sysInfoService.uptime
    property alias shell: sysInfoService.shell
    property alias de: sysInfoService.de
    property alias cpuModel: sysInfoService.cpuModel
    property alias cpuCores: sysInfoService.cpuCores
    property alias cpuThreads: sysInfoService.cpuThreads
    property alias cpuFreq: sysInfoService.cpuFreq
    property alias cpuArch: sysInfoService.cpuArch
    property alias memTotal: sysInfoService.memTotal
    property alias memUsed: sysInfoService.memUsed
    property alias memAvail: sysInfoService.memAvail
    property alias memPercent: sysInfoService.memPercent
    property alias gpuModel: sysInfoService.gpuModel
    property alias gpuDriver: sysInfoService.gpuDriver
    property alias diskTotal: sysInfoService.diskTotal
    property alias diskUsed: sysInfoService.diskUsed
    property alias diskAvail: sysInfoService.diskAvail
    property alias diskPercent: sysInfoService.diskPercent
    property alias swapTotal: sysInfoService.swapTotal
    property alias swapUsed: sysInfoService.swapUsed
    property alias packages: sysInfoService.packages
    property alias initSystem: sysInfoService.initSystem
    property alias profileImagePath: sysInfoService.profileImagePath
    property alias homeDir: sysInfoService.homeDir
    property alias imgCacheBuster: sysInfoService.imgCacheBuster

    // Profile image logic - simplified for portability
    // We strictly use ~/.config/quickshell/assets/profile_avatar.jpg
    
    FileDialog {
        id: profilePicDialog
        title: "Select Profile Picture"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.svg)", "All files (*)"]
        folder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        onAccepted: {
            var selectedFile = profilePicDialog.file.toString().replace("file://", "");
            if (selectedFile !== "") sysInfoService.importProfileImage(selectedFile);
        }
    }

    // ── UI ──
    Flickable {
        anchors.fill: parent
        contentHeight: mainCol.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainCol
            width: parent.width
            anchors.margins: 20
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 16

            // ═══ HEADER ═══
            RowLayout {
                Layout.fillWidth: true
                Text { text: "󰻀"; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
                Text {  text: "System Info"; font.bold: true; font.pixelSize: 18; color: SettingsPalette.text; font.family: Theme.fontFamily }
            }

            // ═══ USER + HOST CARD ═══
            Rectangle {
                Layout.fillWidth: true
                height: 90
                color: SettingsPalette.surface
                radius: 12

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    // Avatar (clickable)
                    Rectangle {
                        width: 62; height: 62; radius: 31
                        color: Qt.rgba(137/255, 180/255, 250/255, 0.2)
                        clip: true

                        Image {
                            id: profileImg
                            anchors.fill: parent
                            source: sysInfoPage.profileImagePath !== "" ? ("file://" + sysInfoPage.profileImagePath + "?t=" + sysInfoPage.imgCacheBuster) : ""
                            visible: sysInfoPage.profileImagePath !== "" && status === Image.Ready
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 124
                            sourceSize.height: 124
                            cache: false
                        }

                        // Fallback icon
                        Text {
                            anchors.centerIn: parent
                            text: "󰀄"
                            font.pixelSize: 28; font.family: "JetBrainsMono Nerd Font"
                            color: Theme.primary
                            visible: !profileImg.visible
                        }

                        // Hover overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: 31
                            color: Qt.rgba(0, 0, 0, 0.4)
                            visible: avatarMA.containsMouse
                            Text {
                                font.family: Theme.fontFamily
                                anchors.centerIn: parent
                                text: "📷"
                                font.pixelSize: 18
                            }
                        }

                        MouseArea {
                            id: avatarMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                profilePicDialog.open();
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Text {
                            font.family: Theme.fontFamily
                            text: sysInfoPage.username || "..."
                            color: SettingsPalette.text; font.bold: true; font.pixelSize: 18
                        }
                        Text {
                            font.family: Theme.fontFamily
                            text: "@" + (sysInfoPage.hostname || "...")
                            color: Theme.primary; font.pixelSize: 13
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Distro badge
                    Rectangle {
                        width: distroRow.width + 20; height: 32; radius: 8
                        color: Qt.rgba(166/255, 227/255, 161/255, 0.12)

                        RowLayout {
                            id: distroRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: sysInfoService.getDistroIcon(sysInfoPage.distro); font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"; color: "#a6e3a1" }
                            Text {  text: sysInfoPage.distro || "..."; color: "#a6e3a1"; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                        }
                    }
                }
            }

            // ═══ OVERVIEW CARDS (quick stats) ═══
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 8
                rowSpacing: 8

                Repeater {
                    model: [
                        { icon: "󰌢", label: "Kernel",   value: sysInfoPage.kernel,  color: "#89b4fa" },
                        { icon: "󰔚", label: "Uptime",   value: sysInfoPage.uptime,  color: "#a6e3a1" },
                        { icon: "󰏖", label: "Packages", value: sysInfoPage.packages, color: "#f9e2af" },
                        { icon: "󰆍", label: "Shell",    value: sysInfoPage.shell,   color: "#cba6f7" }
                    ]

                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        height: 72
                        radius: 10
                        color: Qt.rgba(49/255, 50/255, 68/255, 0.5)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            RowLayout {
                                spacing: 6
                                Text { text: modelData.icon; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"; color: modelData.color }
                                Text {  text: modelData.label; color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.fontFamily }
                            }
                            Text {
                                font.family: Theme.fontFamily
                                text: modelData.value || "..."
                                color: SettingsPalette.text; font.pixelSize: 12; font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // ═══ PROCESSOR ═══
            SystemInfoSection {
                iconText: "󰻠"
                accentColor: "#89b4fa"
                title: "Processor"
                rows: [
                    { label: "Model", value: sysInfoPage.cpuModel },
                    { label: "Cores", value: sysInfoPage.cpuCores + " cores" },
                    { label: "Threads", value: sysInfoPage.cpuThreads + " threads" },
                    { label: "Frequency", value: sysInfoPage.cpuFreq },
                    { label: "Architecture", value: sysInfoPage.cpuArch }
                ]
            }

            // ═══ MEMORY ═══
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: memCol.height + 24
                color: Qt.rgba(49/255, 50/255, 68/255, 0.4)
                radius: 12

                ColumnLayout {
                    id: memCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        spacing: 8
                        Text { text: "󰍛"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: "#a6e3a1" }
                        Text {  text: "Memory (RAM)"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 14; font.family: Theme.fontFamily }
                        Item { Layout.fillWidth: true }
                        Text {
                            font.family: Theme.fontFamily
                            text: Math.round(sysInfoPage.memPercent * 100) + "%"
                            color: sysInfoPage.memPercent > 0.8 ? "#f38ba8" : (sysInfoPage.memPercent > 0.5 ? "#f9e2af" : "#a6e3a1")
                            font.bold: true; font.pixelSize: 13
                        }
                    }

                    // Progress bar
                    Rectangle {
                        Layout.fillWidth: true; height: 8; radius: 4
                        color: Qt.rgba(0,0,0,0.3)
                        Rectangle {
                            width: parent.width * sysInfoPage.memPercent; height: parent.height; radius: 4
                            color: sysInfoPage.memPercent > 0.8 ? "#f38ba8" : (sysInfoPage.memPercent > 0.5 ? "#f9e2af" : "#a6e3a1")
                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.04) }

                    Repeater {
                        model: [
                            { label: "Total",      value: sysInfoPage.memTotal },
                            { label: "Used",  value: sysInfoPage.memUsed },
                            { label: "Available", value: sysInfoPage.memAvail }
                        ]

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            Text {  text: modelData.label + ":"; color: SettingsPalette.subtext; font.pixelSize: 12; Layout.preferredWidth: 100; font.family: Theme.fontFamily }
                            Text {  text: modelData.value || "..."; color: SettingsPalette.text; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                        }
                    }

                    // Swap
                    RowLayout {
                        spacing: 8
                        Text {  text: "Swap:"; color: SettingsPalette.subtext; font.pixelSize: 12; Layout.preferredWidth: 100; font.family: Theme.fontFamily }
                        Text {  text: (sysInfoPage.swapUsed || "...") + " / " + (sysInfoPage.swapTotal || "..."); color: SettingsPalette.text; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                    }
                }
            }

            // ═══ GPU ═══
            SystemInfoSection {
                iconText: "󰢮"
                accentColor: "#cba6f7"
                title: "Graphics Card"
                rows: [
                    { label: "Model", value: sysInfoPage.gpuModel },
                    { label: "Driver", value: sysInfoPage.gpuDriver }
                ]
            }

            // ═══ STORAGE ═══
            SystemInfoSection {
                iconText: "󰋊"
                accentColor: "#fab387"
                title: "Storage"
                badgeText: sysInfoPage.diskPercent || "..."
                rows: [
                    { label: "Total", value: sysInfoPage.diskTotal },
                    { label: "Used", value: sysInfoPage.diskUsed },
                    { label: "Available", value: sysInfoPage.diskAvail }
                ]
                preferredLabelWidth: 100
            }

            // ═══ SYSTEM ═══
            SystemInfoSection {
                iconText: sysInfoService.getDistroIcon(sysInfoPage.distro)
                accentColor: "#94e2d5"
                title: "Environment"
                useSurfaceColor: true
                rows: [
                    { label: "Desktop", value: sysInfoPage.de },
                    { label: "Init", value: sysInfoPage.initSystem },
                    { label: "Shell", value: sysInfoPage.shell },
                    { label: "Distro", value: sysInfoPage.distro }
                ]
            }

            Item { height: 20 }
        }
    }
}
