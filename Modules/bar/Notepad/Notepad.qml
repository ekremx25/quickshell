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
    color: Theme.materialActive
        ? (mouseArea.containsMouse ? Qt.lighter(Theme.notepadColor, 1.08) : Theme.notepadColor)
        : "transparent"
    radius: 12
    border.width: Theme.materialActive && notepadWindow.visible ? 1 : 0
    border.color: Theme.foregroundFor(Theme.notepadColor)

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
        color: Theme.materialActive ? Theme.foregroundFor(root.color)
            : (mouseArea.containsMouse || notepadWindow.visible ? Theme.cpYellow : Theme.cpText)
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
            color: Theme.cpBase
            border.color: Theme.cpYellow
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
                    color: Theme.cpYellow
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
                        color: Theme.cpText
                        font.pixelSize: 13
                        font.family: Theme.fontFamily
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        
                        background: Rectangle {
                            color: Qt.rgba(0,0,0,0.2)
                            radius: 8
                            border.color: parent.activeFocus ? Theme.cpYellow : Theme.withAlpha(Theme.text, 0.1)
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
