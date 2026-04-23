import QtQuick
import QtQuick.Controls
import Qt.labs.platform
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"

Rectangle {
    id: root
    width: 36
    height: 36
    color: "transparent"
    radius: 12

    NotepadService { id: notepadService }

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
    PopupWindow {
        id: notepadWindow
        visible: false
        implicitWidth: 320
        implicitHeight: 400
        color: "transparent"

        anchor.window: root.QsWindow.window
        anchor.onAnchoring: {
            if (!anchor.window) return;
            var win = anchor.window;
            var isVertBar = win.height > win.width;
            var itemPos = win.contentItem.mapFromItem(root, 0, 0);
            if (isVertBar) {
                notepadWindow.anchor.rect.x = -notepadWindow.width - 5;
                notepadWindow.anchor.rect.y = itemPos.y + root.height / 2 - notepadWindow.height / 2;
            } else {
                notepadWindow.anchor.rect.x = Math.max(5, itemPos.x);
                notepadWindow.anchor.rect.y = win.height + 5;
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
                    font.family: Theme.fontFamily
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
                        font.family: Theme.fontFamily
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        
                        background: Rectangle {
                            color: Qt.rgba(0,0,0,0.2)
                            radius: 8
                            border.color: parent.activeFocus ? "#f9e2af" : Qt.rgba(255,255,255,0.1)
                            border.width: 1
                        }

                        text: notepadService.text
                        onTextChanged: notepadService.queueSave(text)
                    }
                }
            }
        }
    }
}
