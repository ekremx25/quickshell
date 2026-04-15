import QtQuick
import Quickshell.Io

Item {
    id: backend

    property real cpuPercent: 0
    property string cpuTempC: "-"
    property string loadData: "-, -, -"
    property string cpuFreqGHz: "-"
    property string governor: "-"
    property string cpuModelName: "Loading..."
    property string vCpuCount: "-"
    property var cpuHistory: []
    property int cpuHistMax: 40

    Process {
        id: staticInfo
        command: ["sh", "-c",
            "model=$(grep 'model name' /proc/cpuinfo | head -n1 | cut -d: -f2 | sed 's/^ //'); " +
            "cores=$(nproc); " +
            "echo \"$model|$cores\""
        ]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var parts = String(data).trim().split("|");
                if (parts.length >= 2) {
                    backend.cpuModelName = parts[0];
                    backend.vCpuCount = parts[1];
                }
            }
        }
    }

    Process {
        id: cpuCalcProc
        command: ["sh", "-c",
            "(grep '^cpu ' /proc/stat; sleep 0.5; grep '^cpu ' /proc/stat) | " +
            "awk '{t=$2+$3+$4+$5+$6+$7+$8; i=$5; if (NR==1){t1=t; i1=i;} else {dt=t-t1; di=i-i1; if(dt>0) print 100*(dt-di)/dt; else print 0;}}'"
        ]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var val = parseFloat(String(data).trim());
                if (isNaN(val)) return;
                backend.cpuPercent = val;
                backend.cpuHistory.push(val);
                if (backend.cpuHistory.length > backend.cpuHistMax) backend.cpuHistory.shift();
            }
        }
    }

    Process {
        id: infoProc
        command: ["sh", "-c",
            "read -r l1 l2 l3 rest < /proc/loadavg; " +
            "freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo 0); " +
            "gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo '-'); " +
            "tpath=$(grep -l 'k10temp' /sys/class/hwmon/hwmon*/name 2>/dev/null | sed 's/name/temp1_input/' | head -n1); " +
            "if [ -z \"$tpath\" ]; then tpath=$(find /sys/class/hwmon/ -name \"temp1_input\" 2>/dev/null | head -n1); fi; " +
            "if [ -z \"$tpath\" ]; then tpath=$(find /sys/class/thermal/ -name \"temp\" 2>/dev/null | head -n1); fi; " +
            "if [ -n \"$tpath\" ]; then temp=$(cat \"$tpath\" 2>/dev/null); else temp=0; fi; " +
            "[ -z \"$temp\" ] && temp=0; " +
            "echo \"$l1, $l2, $l3|$freq|$gov|$temp\""
        ]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var parts = String(data).trim().split("|");
                if (parts.length < 4) return;
                backend.loadData = parts[0];
                var f = parseFloat(parts[1]);
                backend.cpuFreqGHz = (f > 0) ? (f / 1000000).toFixed(1) : "-";
                backend.governor = parts[2];
                var t = parseFloat(parts[3]);
                backend.cpuTempC = (t > 0) ? Math.round(t / 1000) : "-";
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            cpuCalcProc.running = true;
            infoProc.running = true;
        }
    }
}
