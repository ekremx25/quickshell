import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../Widgets"

Rectangle {
    id: root
    
    // APPEARANCE
    implicitWidth: layout.implicitWidth + 24 // More padding
    implicitHeight: 36 // Taller
    radius: 18 // rounded
    
    color: hasActive ? "#cba6f7" : "#45475a" // Mauve if history exists, Surface otherwise
    
    Behavior on color { ColorAnimation { duration: 200 } }
    
    property bool hasActive: clipboardModel.count > 0
    property string currentClip: ""
    
    // Config
    property int maxHistory: 20
    
    // ── Logic: Poll Clipboard ──
    Process {
        id: clipProc
        command: ["wl-paste", "--type", "text/plain", "--no-newline"] // Force text only
        property string output: ""
        stdout: SplitParser {
            onRead: data => { clipProc.output += data; }
        }
        onExited: {
            var text = clipProc.output.trim();
            clipProc.output = "";
            
            if (text !== "" && text !== root.currentClip) {
                root.currentClip = text;
                addToHistory(text);
            }
        }
    }
    
    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            clipProc.running = false
            clipProc.running = true
        }
    }
    
    function addToHistory(text) {
        // Remove if exists to move to top
        for (var i = 0; i < clipboardModel.count; i++) {
            if (clipboardModel.get(i).text === text) {
                clipboardModel.remove(i);
                break;
            }
        }
        
        clipboardModel.insert(0, {text: text});
        
        if (clipboardModel.count > root.maxHistory) {
            clipboardModel.remove(root.maxHistory, clipboardModel.count - root.maxHistory);
        }
    }
    
    function copyToClipboard(text) {
        // Safe copy using printf to avoid shell interpretation issues
        var safeText = text.replace(/'/g, "'\\''");
        copyProc.command = ["sh", "-c", "printf '%s' '" + safeText + "' | wl-copy"];
        copyProc.running = false;
        copyProc.running = true;
        
        // Also update local tracking so we don't duplicate
        root.currentClip = text;
        addToHistory(text);
        popup.visible = false;
    }
    
    Process {
        id: copyProc
        command: []
    }
    
    ListModel { id: clipboardModel }

    // ── UI ──
    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 8
        
        Text {
            text: "" // Clipboard icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 20 // Bigger icon
            color: hasActive ? "#1e1e2e" : "#cdd6f4"
        }
        
        Text {
            text: clipboardModel.count > 0 ? clipboardModel.count : ""
            visible: clipboardModel.count > 0
            font.bold: true
            font.pixelSize: 14 // Bigger count
            color: "#1e1e2e"
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.visible = !popup.visible
    }
    
    // ── POPUP ──
    PopupWindow {
        id: popup
        visible: false
        
        // Improve anchoring
        anchor.window: root.QsWindow.window
        anchor.onAnchoring: {
            if (!anchor.window) return;
            // Center horizontally on the button
            popup.anchor.rect.x = anchor.window.contentItem.mapFromItem(root, 0, 0).x + root.width/2 - popup.width/2
            // Position directly below the bar
            popup.anchor.rect.y = anchor.window.height + 5
        }
        
        implicitWidth: 360
        implicitHeight: Math.min(500, Math.max(150, clipboardModel.count * 50 + 60))
        
        color: "transparent"
        
        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
            radius: 12
            border.color: "#cba6f7"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4
                
                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Clipboard History"; color: "#cba6f7"; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { 
                        text: "Clear All"; color: "#f38ba8"; font.pixelSize: 11
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                clipboardModel.clear();
                                root.currentClip = "";
                                copyProc.command = ["wl-copy", "--clear"];
                                copyProc.running = false;
                                copyProc.running = true;
                            }
                        }
                    }
                }
                
                Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }
                
                // List
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: clipboardModel
                    clip: true
                    spacing: 4
                    
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 50
                        color: hoverMA.containsMouse ? "#313244" : "transparent"
                        radius: 6
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            
                            Text {
                                text: model.text.replace(/\n/g, " ")
                                color: "#cdd6f4"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            
                            Text {
                                text: ""; color: "#a6adc8"; font.family: "JetBrainsMono Nerd Font"
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.copyToClipboard(model.text)
                                }
                            }
                            
                            Text {
                                text: "✕"; color: "#f38ba8"
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: clipboardModel.remove(index)
                                }
                            }
                        }
                        
                        MouseArea {
                            id: hoverMA
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.copyToClipboard(model.text)
                        }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "No history"
                        visible: clipboardModel.count === 0
                        color: "#6c7086"
                    }
                }
            }
        }
    }
}
