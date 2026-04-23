import QtQuick
import Qt.labs.platform
import QtQuick.Layouts
import QtQuick.Controls
import "."

Rectangle {
    id: root
    
    // Public API
    signal fileSelected(string path)
    signal directorySelected(string path)
    signal canceled
    
    // Properties
    property alias currentPath: backend.currentPath
    property var extensions: [] // e.g. ["ovpn", "conf"]
    property string title: "Select File"
    property bool directoryMode: false
    property bool allowCreateFolder: false

    FilePickerBackend {
        id: backend
        extensions: root.extensions
    }
    
    color: "#1e1e2e"
    border.color: Qt.rgba(255,255,255,0.1)
    border.width: 1
    radius: 12
    
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
                Rectangle {
                    width: 54
                    height: 24
                    radius: 6
                    color: Qt.rgba(255,255,255,0.08)
                    Text { anchors.centerIn: parent; text: "Home"; color: Theme.text; font.pixelSize: 11; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.currentPath = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "")
                    }
                }
                Rectangle {
                    width: 40
                    height: 24
                    radius: 6
                    color: Qt.rgba(255,255,255,0.08)
                    Text { anchors.centerIn: parent; text: "Up"; color: Theme.text; font.pixelSize: 11; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.openEntry({ name: "..", isDir: true, path: backend.getParentPath(root.currentPath) })
                    }
                }
                Text {
                    text: root.currentPath
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.directoryMode

            Rectangle {
                Layout.fillWidth: true
                height: 34
                radius: 8
                color: Qt.rgba(255,255,255,0.05)

                Text {
                    anchors.centerIn: parent
                    text: "Use current folder"
                    color: Theme.text
                    font.pixelSize: 12
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.directorySelected(root.currentPath)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.directoryMode && root.allowCreateFolder
            spacing: 8

            TextField {
                id: folderNameField
                Layout.fillWidth: true
                placeholderText: "New folder name"
            }

            Rectangle {
                width: 108
                height: 34
                radius: 8
                color: Qt.rgba(255,255,255,0.1)
                Text { anchors.centerIn: parent; text: "Create"; color: Theme.text; font.pixelSize: 12; font.bold: true }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.createFolder(folderNameField.text);
                        if (backend.actionStatus === "Folder created") folderNameField.text = "";
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: backend.actionStatus.length > 0
            text: backend.actionStatus
            color: Theme.subtext
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }
        
        // File List
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: backend.directoryEntries
            
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

                    Rectangle {
                        visible: root.directoryMode && modelData.isDir && modelData.name !== ".."
                        width: 56
                        height: 22
                        radius: 6
                        color: Qt.rgba(255,255,255,0.10)
                        Text {
                            anchors.centerIn: parent
                            text: "Select"
                            color: Theme.text
                            font.pixelSize: 10
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                mouse.accepted = true;
                                root.directorySelected(modelData.path);
                            }
                        }
                    }
                }
                
                MouseArea {
                    id: itemMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.isDir) {
                            backend.openEntry(modelData);
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
