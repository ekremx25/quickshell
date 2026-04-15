pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // --- 属性 ---
    // 只要有连接类型，就视为已连接
    property bool connected: activeConnectionType != ""
    property string activeConnection: "Disconnected"
    property string activeConnectionType: ""
    // 【已删除】 activeConnectionIcon 属性

    // --- 刷新函数 ---
    function refresh() {
        refreshProcess.running = true;
    }

    // --- 1. 获取状态的进程 ---
    Process {
        id: refreshProcess
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "con", "show", "--active"]
        
        stdout: StdioCollector {
            onStreamFinished: () => {
                // 如果输出为空，说明断网
                if (this.text.trim() === "") {
                    root.activeConnectionType = ""
                    root.activeConnection = "Disconnected"
                    return
                }
                
                // 解析第一行
                const interfaces = this.text.split("\n");
                const activeInterface = interfaces[0];
                const fields = activeInterface.split(":");
                
                if (fields.length < 2) return; 

                // 获取类型
                const connectionType = refreshProcess.getConnectionType(fields[1]);
                root.activeConnectionType = connectionType;
                
                // 获取名称
                root.activeConnection = connectionType != "" ? fields[0] : "Disconnected";
                
                // 【已删除】 设置 activeConnectionIcon 的代码
            }
        }

        // 辅助函数：只保留判断类型
        function getConnectionType(nmcliOutput) {
            if (nmcliOutput.includes("ethernet")) {
                return "ETHERNET";
            } else if (nmcliOutput.includes("wireless")) {
                return "WIFI";
            }
            return "";
        }
        
        // 【已删除】 getConnectionIcon 函数
    }

    // --- 2. 监听进程 ---
    // 这个进程 running: true，一旦网络变化（或启动时），
    // 它的输出会触发 root.refresh()，所以不需要额外的启动代码
    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: root.refresh()
        }
    }
    
    // 【已删除】 Component.onCompleted (这是导致报错的元凶)
}
