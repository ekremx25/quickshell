import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"

ColumnLayout {
    id: root
    spacing: 12

    property string configPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/notes.txt"

    // --- SAVE/LOAD LOGIC ---
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

    function save() {
        writeProc.fileContent = textArea.text;
        // Toggle running to trigger write
        if (writeProc.running) writeProc.running = false;
        writeProc.running = true;
    }

    Component.onCompleted: {
        readProc.running = true;
    }

    // --- UI ---
    Text {
        text: "Not Defteri"
        color: Theme.text || "#cdd6f4"
        font.bold: true
        font.pixelSize: 18
        font.family: "JetBrainsMono Nerd Font"
        Layout.alignment: Qt.AlignHCenter
    }

    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        TextArea {
            id: textArea
            placeholderText: "Buraya not al..."
            color: "#cdd6f4"
            font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font"
            wrapMode: TextEdit.Wrap
            
            background: Rectangle {
                color: Qt.rgba(0,0,0,0.2)
                radius: 8
                border.color: parent.activeFocus ? Theme.primary : Qt.rgba(255,255,255,0.1)
                border.width: 1
            }

            onTextChanged: saveTimer.restart()
        }
    }

    // Debounce save (don't save on every keystroke, wait a bit)
    Timer {
        id: saveTimer
        interval: 1000
        repeat: false
        onTriggered: root.save()
    }
}
