import QtQuick
import Quickshell.Io
import Quickshell
import "../../../Services"

Item {
    id: service
    visible: false
    width: 0
    height: 0

    property string hostname: ""
    property string username: ""
    property string distro: ""
    property string kernel: ""
    property string uptime: ""
    property string shell: ""
    readonly property string desktopSession: Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("DESKTOP_SESSION") || ""
    property string de: detectedDesktop()
    property string initSystem: "systemd"

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
    property string homeDir: ""
    property string profileImagePath: ""
    property int imgCacheBuster: 0

    readonly property string avatarPath: homeDir !== "" ? (homeDir + "/.config/quickshell/assets/profile_avatar.jpg") : ""

    function detectedDesktop() {
        if (CompositorService.isNiri) return "Niri (Wayland)"
        if (CompositorService.isHyprland) return "Hyprland (Wayland)"
        if (CompositorService.isMango) return "MangoWC (Wayland)"
        if (desktopSession !== "") return desktopSession + " (Wayland)"
        return "Wayland"
    }

    function formatBytes(bytes) {
        if (bytes <= 0) return "0 B"
        var units = ["B", "KB", "MB", "GB", "TB"]
        var index = Math.floor(Math.log(bytes) / Math.log(1024))
        return (bytes / Math.pow(1024, index)).toFixed(2) + " " + units[index]
    }

    function getDistroIcon(name) {
        if (!name) return "\ue712"
        var value = name.toLowerCase()
        if (value.indexOf("gentoo") !== -1) return "\ue7e6"
        if (value.indexOf("fedora") !== -1) return "\ue7d9"
        if (value.indexOf("ubuntu") !== -1) return "\uef72"
        if (value.indexOf("debian") !== -1) return "\ue77d"
        if (value.indexOf("arch") !== -1) return "\uf31e"
        if (value.indexOf("nixos") !== -1) return "\ue843"
        if (value.indexOf("opensuse") !== -1) return "\uf314"
        if (value.indexOf("linux mint") !== -1) return "\uf30e"
        if (value.indexOf("elementary") !== -1) return "\uf309"
        return "\ue712"
    }

    function refreshStaticData() {
        if (staticProc.running) return
        staticProc.output = ""
        staticProc.running = true
    }

    function refreshDynamicData() {
        if (dynamicProc.running) return
        dynamicProc.output = ""
        dynamicProc.running = true
    }

    function refreshAll() {
        refreshStaticData()
        refreshDynamicData()
    }

    function parseKeyValueBlock(text) {
        var result = {}
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.length === 0) continue
            var idx = line.indexOf("=")
            if (idx <= 0) continue
            result[line.substring(0, idx)] = line.substring(idx + 1)
        }
        return result
    }

    function applyStaticSnapshot(values) {
        homeDir = values.HOME || homeDir
        hostname = values.HOSTNAME || hostname
        username = values.USERNAME || username
        distro = values.DISTRO || distro
        kernel = values.KERNEL || kernel
        shell = values.SHELL || shell
        cpuModel = values.CPU_MODEL || cpuModel
        cpuThreads = values.CPU_THREADS || cpuThreads
        cpuArch = values.CPU_ARCH || cpuArch
        gpuModel = values.GPU_MODEL || gpuModel
        packages = values.PACKAGES || packages

        var freqMhz = parseFloat(values.CPU_FREQ_MHZ || "0")
        if (!isNaN(freqMhz) && freqMhz > 0) {
            cpuFreq = (freqMhz / 1000).toFixed(2) + " GHz"
        }

        var threads = parseInt(values.CPU_THREADS || "0")
        var threadsPerCore = parseInt(values.CPU_THREADS_PER_CORE || "0")
        if (threads > 0 && threadsPerCore > 0) {
            cpuCores = String(Math.round(threads / threadsPerCore))
        }

        var gpuDriverRaw = values.GPU_DRIVER || ""
        gpuDriver = (gpuDriverRaw && gpuDriverRaw !== "mesa") ? ("NVIDIA " + gpuDriverRaw) : "Mesa (Open Source)"

        profileImagePath = values.PROFILE_IMAGE === "yes" ? avatarPath : ""
    }

    function applyDynamicSnapshot(values) {
        uptime = (values.UPTIME || "").replace(/^up\s+/, "")

        var total = parseInt(values.MEM_TOTAL || "0")
        var used = parseInt(values.MEM_USED || "0")
        var avail = parseInt(values.MEM_AVAIL || "0")
        if (total > 0) {
            memTotal = formatBytes(total)
            memUsed = formatBytes(used)
            memAvail = formatBytes(avail)
            memPercent = Math.max(0, Math.min(1, used / total))
        }

        var swapTotalBytes = parseInt(values.SWAP_TOTAL || "0")
        var swapUsedBytes = parseInt(values.SWAP_USED || "0")
        swapTotal = formatBytes(swapTotalBytes)
        swapUsed = formatBytes(swapUsedBytes)

        diskTotal = values.DISK_TOTAL || diskTotal
        diskUsed = values.DISK_USED || diskUsed
        diskAvail = values.DISK_AVAIL || diskAvail
        diskPercent = values.DISK_PERCENT || diskPercent
    }

    function importProfileImage(selectedFile) {
        if (!selectedFile || selectedFile === "" || avatarPath === "") return
        var targetDir = homeDir + "/.config/quickshell/assets"
        copyProfileProc.command = ["sh", "-c", "mkdir -p \"$1\" && cp \"$2\" \"$3\"", "--", targetDir, selectedFile, avatarPath]
        copyProfileProc.running = true
    }

    Process {
        id: staticProc
        command: [
            "sh",
            "-c",
            "HOME_DIR=\"$HOME\"; " +
            "AVATAR=\"$HOME_DIR/.config/quickshell/assets/profile_avatar.jpg\"; " +
            ". /etc/os-release 2>/dev/null; " +
            "CPU_MODEL=$(lscpu | awk -F: '/Model name/ {sub(/^[ \\t]+/, \"\", $2); print $2; exit}'); " +
            "CPU_THREADS=$(lscpu | awk -F: '/^CPU\\(s\\)/ {sub(/^[ \\t]+/, \"\", $2); print $2; exit}'); " +
            "CPU_TPC=$(lscpu | awk -F: '/Thread\\(s\\) per core/ {sub(/^[ \\t]+/, \"\", $2); print $2; exit}'); " +
            "CPU_FREQ=$(lscpu | awk -F: '/CPU max MHz/ {sub(/^[ \\t]+/, \"\", $2); print $2; exit}'); " +
            "CPU_ARCH=$(lscpu | awk -F: '/Architecture/ {sub(/^[ \\t]+/, \"\", $2); print $2; exit}'); " +
            "GPU_MODEL=$(lspci | grep -i 'vga\\|3d\\|display' | head -1 | sed 's/.*: //'); " +
            "GPU_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo mesa); " +
            "PKGS=$(if command -v qlist >/dev/null; then qlist -I | wc -l; elif command -v pacman >/dev/null; then pacman -Q | wc -l; elif command -v nix-env >/dev/null; then nix-env -q | wc -l; elif command -v xbps-query >/dev/null; then xbps-query -l | wc -l; elif command -v rpm >/dev/null; then rpm -qa | wc -l; elif command -v dpkg >/dev/null; then dpkg -l | grep '^ii' | wc -l; elif command -v apk >/dev/null; then apk info | wc -l; else echo '?'; fi); " +
            "printf 'HOME=%s\\nHOSTNAME=%s\\nUSERNAME=%s\\nDISTRO=%s\\nKERNEL=%s\\nSHELL=%s\\nCPU_MODEL=%s\\nCPU_THREADS=%s\\nCPU_THREADS_PER_CORE=%s\\nCPU_FREQ_MHZ=%s\\nCPU_ARCH=%s\\nGPU_MODEL=%s\\nGPU_DRIVER=%s\\nPACKAGES=%s\\nPROFILE_IMAGE=%s\\n' " +
            "\"$HOME_DIR\" " +
            "\"$(cat /etc/hostname 2>/dev/null || uname -n)\" " +
            "\"$(whoami)\" " +
            "\"${PRETTY_NAME:-${NAME:-Unknown Linux}}\" " +
            "\"$(uname -r)\" " +
            "\"$(basename \"$SHELL\")\" " +
            "\"$CPU_MODEL\" \"$CPU_THREADS\" \"$CPU_TPC\" \"$CPU_FREQ\" \"$CPU_ARCH\" \"$GPU_MODEL\" \"$GPU_DRIVER\" \"$PKGS\" " +
            "\"$(test -f \"$AVATAR\" && echo yes || echo no)\""
        ]
        property string output: ""
        stdout: SplitParser { onRead: data => staticProc.output += data + "\n" }
        onExited: {
            service.applyStaticSnapshot(service.parseKeyValueBlock(staticProc.output))
            staticProc.output = ""
        }
    }

    Process {
        id: dynamicProc
        command: [
            "sh",
            "-c",
            "MEM_TOTAL=$(awk '/MemTotal:/ {print $2 * 1024; exit}' /proc/meminfo); " +
            "MEM_AVAIL=$(awk '/MemAvailable:/ {print $2 * 1024; exit}' /proc/meminfo); " +
            "MEM_USED=$((MEM_TOTAL - MEM_AVAIL)); " +
            "SWAP_TOTAL=$(awk '/SwapTotal:/ {print $2 * 1024; exit}' /proc/meminfo); " +
            "SWAP_FREE=$(awk '/SwapFree:/ {print $2 * 1024; exit}' /proc/meminfo); " +
            "SWAP_USED=$((SWAP_TOTAL - SWAP_FREE)); " +
            "read _ DISK_TOTAL DISK_USED DISK_AVAIL DISK_PERCENT _ <<EOF\n$(df -h / | tail -1)\nEOF\n" +
            "printf 'UPTIME=%s\\nMEM_TOTAL=%s\\nMEM_USED=%s\\nMEM_AVAIL=%s\\nSWAP_TOTAL=%s\\nSWAP_USED=%s\\nDISK_TOTAL=%s\\nDISK_USED=%s\\nDISK_AVAIL=%s\\nDISK_PERCENT=%s\\n' " +
            "\"$(uptime -p)\" \"$MEM_TOTAL\" \"$MEM_USED\" \"$MEM_AVAIL\" \"$SWAP_TOTAL\" \"$SWAP_USED\" \"$DISK_TOTAL\" \"$DISK_USED\" \"$DISK_AVAIL\" \"$DISK_PERCENT\""
        ]
        property string output: ""
        stdout: SplitParser { onRead: data => dynamicProc.output += data + "\n" }
        onExited: {
            service.applyDynamicSnapshot(service.parseKeyValueBlock(dynamicProc.output))
            dynamicProc.output = ""
        }
    }

    Process {
        id: copyProfileProc
        command: []
        onExited: {
            service.imgCacheBuster++
            service.profileImagePath = service.avatarPath
        }
    }

    Component.onCompleted: refreshAll()

    Timer {
        interval: 5000
        running: service.visible === false
        repeat: true
        onTriggered: service.refreshDynamicData()
    }
}
