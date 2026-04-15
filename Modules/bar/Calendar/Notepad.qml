import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../Widgets"

ColumnLayout {
    id: root
    spacing: 12
    CalendarNotesService { id: notesService }

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
            text: notesService.text
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

            onTextChanged: notesService.queueSave(text)
        }
    }
}
