import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property string sourcePath: ""
    property string targetPath: ""

    signal finished(bool success)

    Process {
        id: proc
        command: root.sourcePath.length > 0 && root.targetPath.length > 0
            ? ["sh", "-c", "mkdir -p \"$(dirname \"" + root.targetPath + "\")\" && cp \"" + root.sourcePath + "\" \"" + root.targetPath + "\""]
            : []
        running: false
        onExited: exitCode => {
            root.finished(exitCode === 0);
        }
    }

    function run(sourcePath, targetPath) {
        if (proc.running) return;
        root.sourcePath = sourcePath;
        root.targetPath = targetPath;
        proc.running = true;
    }
}
