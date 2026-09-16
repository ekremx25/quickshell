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
        onClicked: {
            if (!notepadWindow.visible) notepadWindow.positionUnderIcon()
            notepadWindow.visible = !notepadWindow.visible
        }
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
    PanelWindow {
        id: notepadWindow
        screen: root.QsWindow.window ? root.QsWindow.window.screen : null
        anchors { top: true; left: true }
        margins { top: 51; left: 5 }

        function positionUnderIcon() {
            const bar = root.QsWindow.window
            if (!bar || !bar.screen) return
            const pos = bar.contentItem.mapFromItem(root, 0, 0)
            // Resolve the icon inside its bar, including bottom/right bars.
            const offsetX = bar.anchors.right && !bar.anchors.left
                ? bar.screen.width - bar.width : 0
            const offsetY = bar.anchors.bottom && !bar.anchors.top
                ? bar.screen.height - bar.height : 0
            const iconX = offsetX + pos.x
            const iconY = offsetY + pos.y
            margins.left = Math.round(Math.max(5, Math.min(
                iconX + root.width / 2 - implicitWidth / 2,
                bar.screen.width - implicitWidth - 5)))
            // Prefer below; keep the panel visible when the icon is at the bottom.
            const below = iconY + root.height + 5
            margins.top = Math.round(Math.max(5,
                below + implicitHeight <= bar.screen.height - 5
                    ? below : iconY - implicitHeight - 5))
        }

        Timer {
            interval: 100
            repeat: true
            running: notepadWindow.visible
            onTriggered: notepadWindow.positionUnderIcon()
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: {
            if (visible) Qt.callLater(function() {
                notepadWindow.positionUnderIcon()
                textArea.forceActiveFocus()
            })
        }
        visible: false
        implicitWidth: 320
        implicitHeight: 400
        color: "transparent"


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
                        focus: true
                        Keys.onEscapePressed: notepadWindow.visible = false
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
