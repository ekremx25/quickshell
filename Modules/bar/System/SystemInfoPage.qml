
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Qt.labs.platform
import "../../../Widgets"

Item {
    id: sysInfoPage


    // ── Properties ──
    property string hostname: ""
    property string username: ""
    property string distro: ""
    property string kernel: ""
    property string uptime: ""
    property string shell: ""
    property string de: ""

    property string cpuModel: ""
    property string cpuCores: ""
    property string cpuThreads: ""
    property string cpuFreq: ""
    property string cpuArch: ""

    property string memTotal: ""
    property string memUsed: ""
    property string memAvail: ""
    property double memPercent: 0

    property string gpuModel: ""
    property string gpuDriver: ""

    property string diskTotal: ""
    property string diskUsed: ""
    property string diskAvail: ""
    property string diskPercent: ""

    property string swapTotal: ""
    property string swapUsed: ""

    property string packages: ""
    property string initSystem: ""

    // Profile image
    property string profileImagePath: ""
    property string homeDir: ""

    // ── Processes ──

    // Get Home Directory first
    Process {
        id: homeProc
        command: ["sh", "-c", "echo $HOME"]
        stdout: SplitParser { onRead: data => sysInfoPage.homeDir = data.trim() }
        onExited: {
            // Once we have homeDir, we can set the profile image path
            if (sysInfoPage.homeDir !== "") {
                sysInfoPage.profileImagePath = sysInfoPage.homeDir + "/.config/quickshell/assets/profile_avatar.jpg";
            }
        }
    }
    
    // ... (other system info processes: hostname, username etc. - KEEP AS IS)

    Process {
        id: hostnameProc
        command: ["hostname"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { hostnameProc.buf = data.trim(); } }
        onExited: { sysInfoPage.hostname = hostnameProc.buf; }
    }

    Process {
        id: usernameProc
        command: ["whoami"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { usernameProc.buf = data.trim(); } }
        onExited: { sysInfoPage.username = usernameProc.buf; }
    }

    Process {
        id: distroProc
        command: ["sh", "-c", "grep '^PRETTY_NAME=' /etc/os-release | cut -d'\"' -f2"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { distroProc.buf = data.trim(); } }
        onExited: { sysInfoPage.distro = distroProc.buf; }
    }

    Process {
        id: kernelProc
        command: ["uname", "-r"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { kernelProc.buf = data.trim(); } }
        onExited: { sysInfoPage.kernel = kernelProc.buf; }
    }

    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { uptimeProc.buf = data.trim(); } }
        onExited: { sysInfoPage.uptime = uptimeProc.buf.replace("up ", ""); }
    }

    Process {
        id: shellProc
        command: ["sh", "-c", "basename $SHELL"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { shellProc.buf = data.trim(); } }
        onExited: { sysInfoPage.shell = shellProc.buf; }
    }

    Process {
        id: cpuProc
        command: ["sh", "-c", "lscpu | grep -E 'Model name|^CPU\\(s\\)|Thread|CPU max MHz|Architecture' | head -5"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { cpuProc.buf += data + "\n"; } }
        onExited: {
            var lines = cpuProc.buf.split("\n");
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i];
                var parts = line.split(":");
                if (parts.length < 2) continue;
                var key = parts[0].trim();
                var val = parts.slice(1).join(":").trim();

                if (key === "Architecture") sysInfoPage.cpuArch = val;
                else if (key === "CPU(s)") sysInfoPage.cpuThreads = val;
                else if (key.indexOf("Model name") >= 0) sysInfoPage.cpuModel = val;
                else if (key.indexOf("Thread") >= 0) {
                    // Thread(s) per core
                    var tpc = parseInt(val);
                    if (tpc > 0 && sysInfoPage.cpuThreads !== "") {
                        sysInfoPage.cpuCores = String(Math.round(parseInt(sysInfoPage.cpuThreads) / tpc));
                    }
                }
                else if (key.indexOf("CPU max MHz") >= 0) {
                    var mhz = parseFloat(val);
                    sysInfoPage.cpuFreq = (mhz / 1000).toFixed(2) + " GHz";
                }
            }
            cpuProc.buf = "";
        }
    }

    Process {
        id: memProc
        command: ["sh", "-c", "free -b | grep Mem"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { memProc.buf = data.trim(); } }
        onExited: {
            var parts = memProc.buf.split(/\s+/);
            if (parts.length >= 4) {
                var total = parseInt(parts[1]);
                var used = parseInt(parts[2]);
                var avail = parseInt(parts[6] || parts[3]);
                sysInfoPage.memTotal = formatBytes(total);
                sysInfoPage.memUsed = formatBytes(used);
                sysInfoPage.memAvail = formatBytes(avail);
                sysInfoPage.memPercent = total > 0 ? (used / total) : 0;
            }
            memProc.buf = "";
        }
    }

    Process {
        id: swapProc
        command: ["sh", "-c", "free -b | grep Swap"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { swapProc.buf = data.trim(); } }
        onExited: {
            var parts = swapProc.buf.split(/\s+/);
            if (parts.length >= 3) {
                sysInfoPage.swapTotal = formatBytes(parseInt(parts[1]));
                sysInfoPage.swapUsed = formatBytes(parseInt(parts[2]));
            }
            swapProc.buf = "";
        }
    }

    Process {
        id: gpuProc
        command: ["sh", "-c", "lspci | grep -i 'vga\\|3d\\|display' | head -1 | sed 's/.*: //'"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { gpuProc.buf = data.trim(); } }
        onExited: { sysInfoPage.gpuModel = gpuProc.buf; }
    }

    Process {
        id: gpuDriverProc
        command: ["sh", "-c", "nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo 'mesa'"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { gpuDriverProc.buf = data.trim(); } }
        onExited: {
            if (gpuDriverProc.buf && gpuDriverProc.buf !== "mesa") {
                sysInfoPage.gpuDriver = "NVIDIA " + gpuDriverProc.buf;
            } else {
                sysInfoPage.gpuDriver = "Mesa (Open Source)";
            }
        }
    }

    Process {
        id: diskProc
        command: ["sh", "-c", "df -h / | tail -1"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { diskProc.buf = data.trim(); } }
        onExited: {
            var parts = diskProc.buf.split(/\s+/);
            if (parts.length >= 5) {
                sysInfoPage.diskTotal = parts[1];
                sysInfoPage.diskUsed = parts[2];
                sysInfoPage.diskAvail = parts[3];
                sysInfoPage.diskPercent = parts[4];
            }
            diskProc.buf = "";
        }
    }

    Process {
        id: pkgProc
        command: ["sh", "-c", "if command -v qlist >/dev/null; then qlist -I | wc -l; elif command -v pacman >/dev/null; then pacman -Q | wc -l; elif command -v nix-env >/dev/null; then nix-env -q | wc -l; elif command -v xbps-query >/dev/null; then xbps-query -l | wc -l; elif command -v rpm >/dev/null; then rpm -qa | wc -l; elif command -v dpkg >/dev/null; then dpkg -l | grep '^ii' | wc -l; elif command -v apk >/dev/null; then apk info | wc -l; else echo '?'; fi"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { pkgProc.buf = data.trim(); } }
        onExited: { sysInfoPage.packages = pkgProc.buf; }
    }

    // Profile image logic - simplified for portability
    // We strictly use ~/.config/quickshell/assets/profile_avatar.jpg
    
    FileDialog {
        id: profilePicDialog
        title: "Select Profile Picture"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.svg)", "All files (*)"]
        folder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        onAccepted: {
            var selectedFile = profilePicDialog.file.toString().replace("file://", "");
            if (selectedFile !== "") {
                var targetDir = sysInfoPage.homeDir + "/.config/quickshell/assets";
                var targetPath = targetDir + "/profile_avatar.jpg";
                copyProfileProc.command = ["sh", "-c", "mkdir -p '" + targetDir + "' && cp '" + selectedFile + "' '" + targetPath + "'"];
                copyProfileProc.running = true;
            }
        }
    }
    
    // Copy image and reload
    Process {
        id: copyProfileProc
        command: []
        onExited: {
            // Force image reload with cache buster
            sysInfoPage.imgCacheBuster++;
            sysInfoPage.profileImagePath = ""; // Clear to trigger change
            sysInfoPage.profileImagePath = sysInfoPage.homeDir + "/.config/quickshell/assets/profile_avatar.jpg";
        }
    }

    // Cache buster counter
    property int imgCacheBuster: 0

    // ── Helpers ──
    function getDistroIcon(name) {
        if (!name) return "\ue712"; // Generic Tux
        var n = name.toLowerCase();
        if (n.indexOf("gentoo") !== -1) return "\ue7e6";
        if (n.indexOf("fedora") !== -1) return "\ue7d9";
        if (n.indexOf("ubuntu") !== -1) return "\uef72";
        if (n.indexOf("debian") !== -1) return "\ue77d";
        if (n.indexOf("arch") !== -1) return "\uf31e";
        if (n.indexOf("nixos") !== -1) return "\ue843";
        if (n.indexOf("opensuse") !== -1) return "\uf314";
        if (n.indexOf("linux mint") !== -1) return "\uf30e";
        if (n.indexOf("elementary") !== -1) return "\uf309";
        return "\ue712"; // Generic Tux
    }

    function formatBytes(bytes) {
        if (bytes <= 0) return "0 B";
        var units = ["B", "KB", "MB", "GB", "TB"];
        var i = Math.floor(Math.log(bytes) / Math.log(1024));
        return (bytes / Math.pow(1024, i)).toFixed(2) + " " + units[i];
    }

    Component.onCompleted: {
        homeProc.running = true; // Start dynamic path resolution first
        hostnameProc.running = true;
        usernameProc.running = true;
        distroProc.running = true;
        kernelProc.running = true;
        uptimeProc.running = true;
        shellProc.running = true;
        cpuProc.running = true;
        memProc.running = true;
        swapProc.running = true;
        gpuProc.running = true;
        gpuDriverProc.running = true;
        diskProc.running = true;
        pkgProc.running = true;

        sysInfoPage.de = "Niri (Wayland)";
        sysInfoPage.initSystem = "systemd";
    }

    // Refresh timer for dynamic data
    Timer {
        interval: 5000; running: sysInfoPage.visible; repeat: true
        onTriggered: {
            memProc.buf = ""; memProc.running = false; memProc.running = true;
            swapProc.buf = ""; swapProc.running = false; swapProc.running = true;
            diskProc.buf = ""; diskProc.running = false; diskProc.running = true;
            uptimeProc.buf = ""; uptimeProc.running = false; uptimeProc.running = true;
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
                Text { text: "System Info"; font.bold: true; font.pixelSize: 18; color: Theme.text }
            }

            // ═══ USER + HOST CARD ═══
            Rectangle {
                Layout.fillWidth: true
                height: 90
                color: Theme.surface
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
                            text: sysInfoPage.username || "..."
                            color: Theme.text; font.bold: true; font.pixelSize: 18
                        }
                        Text {
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
                            Text { text: sysInfoPage.getDistroIcon(sysInfoPage.distro); font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"; color: "#a6e3a1" }
                            Text { text: sysInfoPage.distro || "..."; color: "#a6e3a1"; font.pixelSize: 12; font.bold: true }
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
                                Text { text: modelData.label; color: Theme.subtext; font.pixelSize: 11 }
                            }
                            Text {
                                text: modelData.value || "..."
                                color: Theme.text; font.pixelSize: 12; font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // ═══ PROCESSOR ═══
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: cpuCol.height + 24
                color: Qt.rgba(49/255, 50/255, 68/255, 0.4)
                radius: 12

                ColumnLayout {
                    id: cpuCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        spacing: 8
                        Text { text: "󰻠"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: "#89b4fa" }
                        Text { text: "Processor"; color: Theme.text; font.bold: true; font.pixelSize: 14 }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.04) }

                    Repeater {
                        model: [
                            { label: "Model",      value: sysInfoPage.cpuModel },
                            { label: "Cores",   value: sysInfoPage.cpuCores + " cores" },
                            { label: "Threads", value: sysInfoPage.cpuThreads + " threads" },
                            { label: "Frequency",    value: sysInfoPage.cpuFreq },
                            { label: "Architecture",     value: sysInfoPage.cpuArch }
                        ]

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: modelData.label + ":"; color: Theme.subtext; font.pixelSize: 12; Layout.preferredWidth: 80 }
                            Text { text: modelData.value || "..."; color: Theme.text; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                    }
                }
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
                        Text { text: "Memory (RAM)"; color: Theme.text; font.bold: true; font.pixelSize: 14 }
                        Item { Layout.fillWidth: true }
                        Text {
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
                            Text { text: modelData.label + ":"; color: Theme.subtext; font.pixelSize: 12; Layout.preferredWidth: 100 }
                            Text { text: modelData.value || "..."; color: Theme.text; font.pixelSize: 12; font.bold: true }
                        }
                    }

                    // Swap
                    RowLayout {
                        spacing: 8
                        Text { text: "Swap:"; color: Theme.subtext; font.pixelSize: 12; Layout.preferredWidth: 100 }
                        Text { text: (sysInfoPage.swapUsed || "...") + " / " + (sysInfoPage.swapTotal || "..."); color: Theme.text; font.pixelSize: 12; font.bold: true }
                    }
                }
            }

            // ═══ GPU ═══
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: gpuCol.height + 24
                color: Qt.rgba(49/255, 50/255, 68/255, 0.4)
                radius: 12

                ColumnLayout {
                    id: gpuCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        spacing: 8
                        Text { text: "󰢮"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: "#cba6f7" }
                        Text { text: "Graphics Card"; color: Theme.text; font.bold: true; font.pixelSize: 14 }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.04) }

                    Repeater {
                        model: [
                            { label: "Model",   value: sysInfoPage.gpuModel },
                            { label: "Driver",  value: sysInfoPage.gpuDriver }
                        ]

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: modelData.label + ":"; color: Theme.subtext; font.pixelSize: 12; Layout.preferredWidth: 80 }
                            Text { text: modelData.value || "..."; color: Theme.text; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                    }
                }
            }

            // ═══ STORAGE ═══
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: diskCol.height + 24
                color: Qt.rgba(49/255, 50/255, 68/255, 0.4)
                radius: 12

                ColumnLayout {
                    id: diskCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        spacing: 8
                        Text { text: "󰋊"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: "#fab387" }
                        Text { text: "Storage"; color: Theme.text; font.bold: true; font.pixelSize: 14 }
                        Item { Layout.fillWidth: true }
                        Text { text: sysInfoPage.diskPercent || "..."; color: "#fab387"; font.bold: true; font.pixelSize: 13 }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.04) }

                    Repeater {
                        model: [
                            { label: "Total",      value: sysInfoPage.diskTotal },
                            { label: "Used",  value: sysInfoPage.diskUsed },
                            { label: "Available", value: sysInfoPage.diskAvail }
                        ]

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: modelData.label + ":"; color: Theme.subtext; font.pixelSize: 12; Layout.preferredWidth: 100 }
                            Text { text: modelData.value || "..."; color: Theme.text; font.pixelSize: 12; font.bold: true }
                        }
                    }
                }
            }

            // ═══ SYSTEM ═══
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: envCol.height + 24
                color: Theme.surface
                radius: 12

                ColumnLayout {
                    id: envCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        spacing: 8
                        Text { text: sysInfoPage.getDistroIcon(sysInfoPage.distro); font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: "#94e2d5" }
                        Text { text: "Environment"; color: Theme.text; font.bold: true; font.pixelSize: 14 }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.04) }

                    Repeater {
                        model: [
                            { label: "Desktop",   value: sysInfoPage.de },
                            { label: "Init",        value: sysInfoPage.initSystem },
                            { label: "Shell",        value: sysInfoPage.shell },
                            { label: "Distro",     value: sysInfoPage.distro }
                        ]

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: modelData.label + ":"; color: Theme.subtext; font.pixelSize: 12; Layout.preferredWidth: 80 }
                            Text { text: modelData.value || "..."; color: Theme.text; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                    }
                }
            }

            Item { height: 20 }
        }
    }
}
