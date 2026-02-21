import QtQuick
import Qt.labs.platform
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    
    // Public API
    signal fileSelected(string path)
    signal canceled
    
    // Properties
    property string currentPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") // Start at home
    property var extensions: [] // e.g. ["ovpn", "conf"]
    property string title: "Select File"
    
    // Internal
    property var directoryEntries: []
    // Theme { id: theme }
    
    color: "#1e1e2e"
    border.color: Qt.rgba(255,255,255,0.1)
    border.width: 1
    radius: 12
    
    // Initial load
    Component.onCompleted: listDir(currentPath)
    
    // Process to list directory
    Process {
        id: lsProcess
        command: []
        property string buf: ""
        stdout: SplitParser { onRead: (data) => lsProcess.buf += data + "\n" }
        onExited: {
            // Wait for full output (simple strategy)
            parseLsOutput(lsProcess.buf);
            lsProcess.buf = "";
        }
    }
    
    function listDir(path) {
        // ls -1 -p --group-directories-first
        lsProcess.command = ["ls", "-1", "-p", "--group-directories-first", path];
        lsProcess.running = true;
    }
    
    function parseLsOutput(output) {
        var lines = output.split("\n");
        var newEntries = [];
        
        // Add ".." entry if not at root
        if (currentPath !== "/") {
            newEntries.push({ name: "..", isDir: true, path: getParentPath(currentPath) });
        }
        
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "") continue;
            
            var isDir = line.endsWith("/");
            var name = isDir ? line.slice(0, -1) : line;
            var fullPath = (currentPath === "/" ? "" : currentPath) + "/" + name;
            
            // Filter files if extensions are set
            if (!isDir && extensions.length > 0) {
                var ext = name.split(".").pop().toLowerCase();
                var found = false;
                for(var j=0; j<extensions.length; j++) {
                    if (extensions[j].toLowerCase() === ext) { found = true; break; }
                }
                if (!found) continue;
            }
            
            newEntries.push({ name: name, isDir: isDir, path: fullPath });
        }
        
        directoryEntries = newEntries;
    }
    
    function getParentPath(path) {
        if (path === "/") return "/";
        var parts = path.split("/");
        parts.pop();
        var parent = parts.join("/");
        return parent === "" ? "/" : parent;
    }
    
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 16
        spacing: 12
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            Text { 
                text: root.title
                color: Theme.text
                font.bold: true
                font.pixelSize: 16
            }
            Item { Layout.fillWidth: true }
            Text { 
                text: "✕"
                color: Theme.subtext
                font.pixelSize: 16
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.canceled()
                }
            }
        }
        
        // Current Path Display
        Rectangle {
            Layout.fillWidth: true
            height: 36
            color: Qt.rgba(255,255,255,0.05)
            radius: 8
            
            RowLayout {
                anchors.fill: parent; anchors.margins: 8
                Text {
                    text: root.currentPath
                    color: Theme.subtext
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }
        
        // File List
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.directoryEntries
            
            delegate: Rectangle {
                width: ListView.view.width
                height: 36
                color: itemMa.containsMouse ? Qt.rgba(255,255,255,0.05) : "transparent"
                radius: 6
                
                required property var modelData
                
                RowLayout {
                    anchors.fill: parent; anchors.margins: 8
                    spacing: 10
                    
                    Text {
                        text: modelData.isDir ? "" : "📄"
                        color: modelData.isDir ? Theme.primary : Theme.text
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    
                    Text {
                        text: modelData.name
                        color: Theme.text
                        font.bold: modelData.isDir
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
                
                MouseArea {
                    id: itemMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.isDir) {
                            if (modelData.name === "..") {
                                root.currentPath = modelData.path;
                            } else {
                                root.currentPath = (root.currentPath === "/" ? "" : root.currentPath) + "/" + modelData.name;
                            }
                            lsProcess.buf = "";
                            root.listDir(root.currentPath);
                        } else {
                            root.fileSelected(modelData.path);
                        }
                    }
                }
            }
            
            ScrollBar.vertical: ScrollBar { 
                active: true
                width: 10
            }
        }
        
        // Action Buttons
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 80; height: 36; radius: 8
                color: Qt.rgba(255,255,255,0.1)
                Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.text }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.canceled()
                }
            }
        }
    }
}
