import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Services/core/Log.js" as Log

Item {
    id: service
    visible: false
    width: 0
    height: 0

    property var disks: []
    property var rawDisks: []
    property var fstabEntries: ({})
    property int userId: 1000
    property int groupId: 1000
    property string actionStatus: ""
    property string busyDeviceName: ""
    readonly property string helperScriptPath: (Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config")) + "/quickshell/scripts/disk_fstab_helper.sh"

    function refresh() {
        if (!idProc.running && userIdProcPending) {
            idProc.running = true;
            userIdProcPending = false;
        }
        fstabProc.output = "";
        fstabProc.running = false;
        fstabProc.running = true;

        diskListProc.output = "";
        diskListProc.running = false;
        diskListProc.running = true;
    }

    property bool userIdProcPending: true

    function sanitizeSegment(text) {
        var value = String(text || "").trim().toLowerCase();
        value = value.replace(/[^a-z0-9._-]+/g, "-").replace(/^-+|-+$/g, "");
        return value.length > 0 ? value : "disk";
    }

    function defaultMountPoint(disk) {
        var segment = sanitizeSegment(disk.label || disk.name || "disk");
        return "/mnt/" + segment;
    }

    function mountLabel(disk) {
        if (disk.inFstab) return disk.mountpoint ? "Persistent" : "Mount";
        return "Bind to fstab";
    }

    function canPersist(disk) {
        return !!disk && !!disk.uuid && !disk.isSystemMount;
    }

    function mountOptionsFor(disk) {
        var fs = String(disk.fstype || "").toLowerCase();
        if (fs === "ntfs") return "uid=" + userId + ",gid=" + groupId + ",umask=022,windows_names,nofail,x-gvfs-show";
        if (fs === "vfat") return "uid=" + userId + ",gid=" + groupId + ",umask=022,shortname=mixed,utf8=1,nofail,x-gvfs-show";
        if (fs === "exfat") return "uid=" + userId + ",gid=" + groupId + ",umask=022,nofail,x-gvfs-show";
        if (fs === "ext4" || fs === "xfs" || fs === "btrfs") return "defaults,nofail";
        return "defaults,nofail";
    }

    function mountFsTypeFor(disk) {
        var fs = String(disk.fstype || "").toLowerCase();
        if (fs === "ntfs") return "ntfs3";
        return fs.length > 0 ? fs : "auto";
    }

    function parseFstab(text) {
        var map = {};
        var lines = String(text || "").split("\n");
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim();
            if (line.length === 0 || line.indexOf("#") === 0) continue;
            var parts = line.split(/\s+/);
            if (parts.length < 4) continue;
            if (parts[0].indexOf("UUID=") !== 0) continue;
            var uuid = parts[0].substring(5);
            map[uuid] = {
                mountpoint: parts[1],
                fstype: parts[2],
                options: parts[3],
                raw: line
            };
        }
        return map;
    }

    function updateDisks() {
        var nextList = [];
        for (var i = 0; i < rawDisks.length; ++i) {
            var disk = rawDisks[i];
            var fstabEntry = disk.uuid ? fstabEntries[disk.uuid] : null;
            var mountpoint = disk.mountpoint || (fstabEntry ? fstabEntry.mountpoint : "");
            var isSystemMount = mountpoint === "/" || mountpoint === "/boot" || mountpoint.indexOf("/run") === 0;
            nextList.push({
                name: disk.name,
                devPath: "/dev/" + disk.name,
                size: disk.size,
                type: disk.type,
                mountpoint: disk.mountpoint || "",
                displayMountpoint: mountpoint,
                fstype: disk.fstype || "",
                fsavail: disk.fsavail || "",
                fsused: disk.fsused || "",
                usePercent: disk.usePercent || "",
                uuid: disk.uuid || "",
                label: disk.label || "",
                inFstab: !!fstabEntry,
                fstabMountpoint: fstabEntry ? fstabEntry.mountpoint : "",
                fstabOptions: fstabEntry ? fstabEntry.options : "",
                isSystemMount: isSystemMount
            });
        }
        disks = nextList;
    }

    function processDevices(devices, nextList) {
        for (var i = 0; i < devices.length; i++) {
            var dev = devices[i];
            if (dev.type === "part" || (dev.type === "disk" && !dev.children) || dev.type === "lvm") {
                nextList.push({
                    name: dev.name,
                    size: dev.size,
                    type: dev.type,
                    mountpoint: dev.mountpoint || "",
                    fstype: dev.fstype || "",
                    fsavail: dev.fsavail || "",
                    fsused: dev.fsused || "",
                    usePercent: dev["fsuse%"] || "",
                    uuid: dev.uuid || "",
                    label: dev.label || ""
                });
            }
            if (dev.children) processDevices(dev.children, nextList);
        }
    }

    function bindToFstab(disk, mountpoint) {
        if (!canPersist(disk)) {
            actionStatus = "This disk cannot be managed from fstab";
            return;
        }
        var targetMount = String(mountpoint || "").trim();
        if (targetMount.length === 0 || targetMount.indexOf("/") !== 0) {
            actionStatus = "Mount point must be an absolute path";
            return;
        }

        var fsType = mountFsTypeFor(disk);
        var fsOptions = mountOptionsFor(disk);
        busyDeviceName = disk.name;
        actionStatus = "Binding " + disk.name + " to fstab...";

        persistProc.command = [
            "pkexec", helperScriptPath, "bind",
            disk.uuid, targetMount, fsType, fsOptions
        ];
        persistProc.output = "";
        persistProc.running = false;
        persistProc.running = true;
    }

    function mountExisting(disk) {
        if (!disk || !disk.inFstab) return;
        busyDeviceName = disk.name;
        actionStatus = "Mounting " + disk.name + "...";
        mountExistingProc.command = [
            "pkexec", helperScriptPath, "mount",
            disk.uuid, disk.fstabMountpoint
        ];
        mountExistingProc.output = "";
        mountExistingProc.running = false;
        mountExistingProc.running = true;
    }

    function unmountDisk(disk) {
        if (!disk || !disk.mountpoint || disk.isSystemMount) return;
        busyDeviceName = disk.name;
        actionStatus = disk.inFstab
            ? ("Removing " + disk.name + " from fstab...")
            : ("Unmounting " + disk.name + "...");
        if (disk.inFstab && disk.uuid) {
            unmountProc.command = [
                "pkexec", helperScriptPath, "unmount-remove",
                disk.uuid, disk.mountpoint, disk.devPath
            ];
        } else {
            unmountProc.command = [
                "pkexec", helperScriptPath, "unmount",
                disk.mountpoint, disk.devPath
            ];
        }
        unmountProc.output = "";
        unmountProc.running = false;
        unmountProc.running = true;
    }

    Process {
        id: idProc
        command: ["sh", "-c", "printf 'UID=%s\\nGID=%s\\n' \"$(id -u)\" \"$(id -g)\""]
        running: false
        property string output: ""
        stdout: SplitParser { onRead: data => idProc.output += data }
        onExited: {
            var lines = idProc.output.trim().split("\n");
            for (var i = 0; i < lines.length; ++i) {
                if (lines[i].indexOf("UID=") === 0) service.userId = parseInt(lines[i].substring(4)) || service.userId;
                if (lines[i].indexOf("GID=") === 0) service.groupId = parseInt(lines[i].substring(4)) || service.groupId;
            }
            idProc.output = "";
        }
    }

    Process {
        id: fstabProc
        property string output: ""
        command: ["sh", "-c", "cat /etc/fstab 2>/dev/null || true"]
        running: false
        stdout: SplitParser { onRead: data => fstabProc.output += data }
        onExited: {
            service.fstabEntries = service.parseFstab(fstabProc.output);
            service.updateDisks();
            fstabProc.output = "";
        }
    }

    Process {
        id: diskListProc
        property string output: ""
        command: ["lsblk", "-J", "-o", "NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,FSAVAIL,FSUSED,FSUSE%,UUID,LABEL"]
        running: false
        stdout: SplitParser { onRead: data => diskListProc.output += data }
        onExited: {
            try {
                if (diskListProc.output.trim() === "") return;
                var json = JSON.parse(diskListProc.output);
                var nextList = [];
                if (json.blockdevices) processDevices(json.blockdevices, nextList);
                service.rawDisks = nextList;
                service.updateDisks();
            } catch (e) {
                Log.warn("DiskService", "JSON parse error: " + e);
            }
            diskListProc.output = "";
        }
    }

    Process {
        id: persistProc
        property string output: ""
        command: []
        running: false
        stdout: SplitParser { onRead: data => persistProc.output += data + "\n" }
        stderr: SplitParser { onRead: data => persistProc.output += data + "\n" }
        onExited: code => {
            if (code === 0) {
                actionStatus = persistProc.output.indexOf("EXISTS") !== -1
                    ? "Disk already exists in fstab and was mounted"
                    : "Disk added to fstab and mounted";
            } else {
                actionStatus = "Failed to bind disk: " + persistProc.output.trim();
                Log.warn("DiskService", actionStatus);
            }
            busyDeviceName = "";
            persistProc.output = "";
            refresh();
        }
    }

    Process {
        id: mountExistingProc
        property string output: ""
        command: []
        running: false
        stdout: SplitParser { onRead: data => mountExistingProc.output += data + "\n" }
        stderr: SplitParser { onRead: data => mountExistingProc.output += data + "\n" }
        onExited: code => {
            if (code === 0) {
                actionStatus = "Disk mounted from fstab";
            } else {
                actionStatus = "Failed to mount disk: " + mountExistingProc.output.trim();
                Log.warn("DiskService", actionStatus);
            }
            busyDeviceName = "";
            mountExistingProc.output = "";
            refresh();
        }
    }

    Process {
        id: unmountProc
        property string output: ""
        command: []
        running: false
        stdout: SplitParser { onRead: data => unmountProc.output += data + "\n" }
        stderr: SplitParser { onRead: data => unmountProc.output += data + "\n" }
        onExited: code => {
            if (code === 0) {
                actionStatus = unmountProc.output.indexOf("REMOVED") !== -1
                    ? "Disk unmounted and removed from fstab"
                    : "Disk unmounted";
            } else {
                actionStatus = "Failed to unmount disk: " + unmountProc.output.trim();
                Log.warn("DiskService", actionStatus);
            }
            busyDeviceName = "";
            unmountProc.output = "";
            refresh();
        }
    }

    Component.onCompleted: refresh()
}
