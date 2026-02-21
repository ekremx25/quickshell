import QtQuick
import QtQuick.Controls
import Qt.labs.platform
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../Widgets"

Rectangle {
    id: root
    width: 36
    height: 36
    color: "transparent"
    radius: 12

    property string configPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/notes.txt"

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: notepadWindow.visible = !notepadWindow.visible
    }

    Text {
        anchors.centerIn: parent
        text: "󰠮" // Notepad icon
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 20
        color: mouseArea.containsMouse || notepadWindow.visible ? "#f9e2af" : "#cdd6f4" // Yellow accent on hover/active
    }
    
    // --- NOTEPAD WINDOW ---
    PanelWindow {
        id: notepadWindow
        visible: false
        implicitWidth: 320
        implicitHeight: 400
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors {
            top: true
            left: true
        }

        // Position relative to button
        margins {
            top: 58
            left: 0 
        }

        // Auto-position logic (similar to Calendar)
        Component.onCompleted: {
            if (root.QsWindow && root.QsWindow.window) {
                var globalPos = root.mapToGlobal(0, 0);
                notepadWindow.margins.left = globalPos.x - (notepadWindow.width / 2) + (root.width / 2);
                if (notepadWindow.margins.left < 10) notepadWindow.margins.left = 10;
            }
        }
        onVisibleChanged: {
            if (visible && root.QsWindow && root.QsWindow.window) {
                var globalPos = root.mapToGlobal(0, 0);
                notepadWindow.margins.left = globalPos.x - (notepadWindow.width / 2) + (root.width / 2);
                 if (notepadWindow.margins.left < 10) notepadWindow.margins.left = 10;
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
            border.color: "#f9e2af"
            border.width: 2
            radius: 12

            // Click blocker behind children
            MouseArea {
                anchors.fill: parent
                z: -1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text {
                    text: "Notepad"
                    color: "#f9e2af"
                    font.bold: true
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    Layout.alignment: Qt.AlignHCenter
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextArea {
                        id: textArea
                        placeholderText: "Take a note here..."
                        color: "#cdd6f4"
                        font.pixelSize: 13
                        font.family: "JetBrainsMono Nerd Font"
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        
                        background: Rectangle {
                            color: Qt.rgba(0,0,0,0.2)
                            radius: 8
                            border.color: parent.activeFocus ? "#f9e2af" : Qt.rgba(255,255,255,0.1)
                            border.width: 1
                        }

                        onTextChanged: saveTimer.restart()
                        Component.onCompleted: readProc.running = true
                    }
                }
            }
        }
    }

    // --- LOGIC ---
    Process {
        id: readProc
        command: ["cat", root.configPath]
        property string output: ""
        stdout: SplitParser { onRead: data => readProc.output += data }
        onExited: {
            textArea.text = readProc.output;
        }
    }

    Process {
        id: writeProc
        property string fileContent: ""
        command: ["bash", "-c", "cat > " + root.configPath + " << 'EOF'\n" + fileContent + "\nEOF"]
    }

    Timer {
        id: saveTimer
        interval: 1000
        repeat: false
        onTriggered: {
            writeProc.fileContent = textArea.text;
            if (writeProc.running) writeProc.running = false;
            writeProc.running = true;
        }
    }
}
