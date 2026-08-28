import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "."
import "../../../Widgets"

Rectangle {
    id: root
    
    // APPEARANCE
    implicitWidth: layout.implicitWidth + 24 // More padding
    implicitHeight: 36 // Taller
    radius: 18 // rounded
    
    readonly property color contentColor: Theme.foregroundFor(Theme.clipboardColor)
    color: Theme.clipboardColor
    Behavior on color { ColorAnimation { duration: Theme.animMedium } }
    opacity: hasActive ? 1 : 0.74
    
    Behavior on opacity { NumberAnimation { duration: 180 } }
    
    ClipboardBackend { id: backend }
    property alias hasActive: backend.hasActive
    property alias currentClip: backend.currentClip
    property alias maxHistory: backend.maxHistory
    property alias clipboardModel: backend.historyModel

    function copyToClipboard(text) {
        backend.copyToClipboard(text);
        popup.visible = false;
    }

    // ── UI ──
    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 8
        
        Text {
            text: "" // Clipboard icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 20 // Bigger icon
            color: root.contentColor
        }
        
        Text {
            font.family: Theme.fontFamily
            text: clipboardModel.count > 0 ? clipboardModel.count : ""
            visible: clipboardModel.count > 0
            font.bold: true
            font.pixelSize: 14 // Bigger count
            color: root.contentColor
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
            var isVertBar = anchor.window.height > anchor.window.width
            if (isVertBar) {
                popup.anchor.rect.x = -popup.width - 5
                popup.anchor.rect.y = anchor.window.contentItem.mapFromItem(root, 0, 0).y + root.height/2 - popup.height/2
            } else {
                popup.anchor.rect.x = anchor.window.contentItem.mapFromItem(root, 0, 0).x + root.width/2 - popup.width/2
                popup.anchor.rect.y = anchor.window.height + 5
            }
        }
        
        implicitWidth: 360
        implicitHeight: Math.min(500, Math.max(150, clipboardModel.count * 50 + 60))
        
        color: "transparent"
        
        Rectangle {
            anchors.fill: parent
            color: Theme.background
            radius: 12
            border.color: Theme.clipboardColor
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4
                
                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {  text: "Clipboard History"; color: Theme.clipboardColor; font.bold: true; font.family: Theme.fontFamily }
                    Item { Layout.fillWidth: true }
                    Text { 
                        font.family: Theme.fontFamily
                        text: "Clear All"; color: Theme.red; font.pixelSize: 11
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                backend.clearHistory();
                            }
                        }
                    }
                    // Kapat butonu
                    Rectangle {
                        width: 22; height: 22; radius: 11
                        color: closeMA.containsMouse ? Theme.surface : "transparent"
                        Text {
                            font.family: Theme.fontFamily
                            anchors.centerIn: parent
                            text: "✕"; color: Theme.subtext; font.pixelSize: 12
                        }
                        MouseArea {
                            id: closeMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popup.visible = false
                        }
                    }
                }
                
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }
                
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
                        color: hoverMA.containsMouse ? Theme.surface : "transparent"
                        radius: 6
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            
                            Text {
                                font.family: Theme.fontFamily
                                text: model.text.replace(/\n/g, " ")
                                color: Theme.text
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            
                            Text {
                                text: ""; color: Theme.subtext; font.family: "JetBrainsMono Nerd Font"
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.copyToClipboard(model.text)
                                }
                            }
                            
                            Text {
                                font.family: Theme.fontFamily
                                text: "✕"; color: Theme.red
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.removeAt(index)
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
                        font.family: Theme.fontFamily
                        anchors.centerIn: parent
                        text: "No history"
                        visible: clipboardModel.count === 0
                        color: Theme.subtext
                    }
                }
            }
        }
    }
}
