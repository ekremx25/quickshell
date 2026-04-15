import QtQuick
import Quickshell.Io

Item {
    id: backend

    property int gpuPercent: 0
    property string gpuTemp: "-"
    property string vramUsed: "-"
    property string vramTotal: "-"
    property string gpuModel: "Loading..."
    property string gpuDriver: "-"
    property string gpuClock: "-"
    property string gpuMemClock: "-"
    property string gpuPower: "-"
    property var gpuHistory: []
    property int gpuHistMax: 40

    Process {
        id: gpuProc
        command: ["sh", "-c",
            "card=$(ls -d /sys/class/drm/card0/device 2>/dev/null); " +
            "if [ ! -f \"$card/mem_info_vram_used\" ]; then card=$(ls -d /sys/class/drm/card1/device 2>/dev/null); fi; " +
            "usage=$(cat \"$card/gpu_busy_percent\" 2>/dev/null || echo 0); " +
            "tempFile=$(find \"$card/hwmon\" -name \"temp1_input\" 2>/dev/null | head -n1); " +
            "if [ -n \"$tempFile\" ]; then temp=$(awk '{print int($1/1000)}' \"$tempFile\"); else temp='-'; fi; " +
            "used=$(cat \"$card/mem_info_vram_used\" 2>/dev/null || echo 0); " +
            "total=$(cat \"$card/mem_info_vram_total\" 2>/dev/null || echo 1); " +
            "usedGB=$(awk -v u=$used 'BEGIN {printf \"%.1f\", u/1073741824}'); " +
            "totalGB=$(awk -v t=$total 'BEGIN {printf \"%.1f\", t/1073741824}'); " +
            "model=$(cat \"$card/../*/product_name\" 2>/dev/null || lspci | grep -i vga | sed 's/.*: //' | head -n1); " +
            "sclk=$(cat \"$card/pp_dpm_sclk\" 2>/dev/null | grep '\\*' | awk '{print $2}'); " +
            "mclk=$(cat \"$card/pp_dpm_mclk\" 2>/dev/null | grep '\\*' | awk '{print $2}'); " +
            "if [ -z \"$sclk\" ]; then sclk='-'; fi; " +
            "if [ -z \"$mclk\" ]; then mclk='-'; fi; " +
            "powerFile=$(find \"$card/hwmon\" -name \"power1_average\" 2>/dev/null | head -n1); " +
            "if [ -n \"$powerFile\" ]; then power=$(awk '{printf \"%.0f\", $1/1000000}' \"$powerFile\"); else power='-'; fi; " +
            "drv=$(basename $(readlink \"$card/driver\") 2>/dev/null || echo '-'); " +
            "echo \"$usage|$temp|$usedGB|$totalGB|$model|$sclk|$mclk|$power|$drv\""
        ]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var parts = String(data).trim().split("|");
                if (parts.length < 4) return;
                var pct = parseInt(parts[0]);
                backend.gpuPercent = isNaN(pct) ? 0 : pct;
                backend.gpuTemp = parts[1];
                backend.vramUsed = parts[2];
                backend.vramTotal = parts[3];
                if (parts.length >= 9) {
                    backend.gpuModel = parts[4] || "-";
                    backend.gpuClock = parts[5] || "-";
                    backend.gpuMemClock = parts[6] || "-";
                    backend.gpuPower = parts[7] || "-";
                    backend.gpuDriver = parts[8] || "-";
                }
                backend.gpuHistory.push(backend.gpuPercent);
                if (backend.gpuHistory.length > backend.gpuHistMax) backend.gpuHistory.shift();
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: gpuProc.running = true
    }
}
