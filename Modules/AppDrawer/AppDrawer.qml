import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../Widgets"
import "../../Services"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    
    property bool isOpened: false
    
    // Provide a transparent background so it doesn't dim the screen.
    color: "transparent"

    visible: false
    
    Timer {
        id: hideTimer
        interval: 150
        onTriggered: {
            root.visible = false
            searchInput.text = ""
        }
    }
    
    // Click outside to close
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (isOpened) root.toggle()
        }
    }
    
    Connections {
        target: AppDrawerState
        function onToggleRequested() {
            root.toggle()
        }
    }
    
    // Allow triggering from external CLI commands (e.g. from Niri hotkey)
    IpcHandler {
        target: "appdrawer"
        function toggle() {
            root.toggle()
        }
    }
    
    // --- Application Data Model ---
    ListModel {
        id: appsModel
    }
    
    property var allApps: []
    
    // --- Application Loader ---
    Process {
        id: appLoader
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/get-apps.sh"]
        property string rawOutput: ""
        
        stdout: SplitParser {
            onRead: (data) => appLoader.rawOutput += data
        }
        
        onExited: {
            if (appLoader.rawOutput.trim() === "") return;
            try {
                var json = JSON.parse(appLoader.rawOutput);
                root.allApps = json;
                refreshModel("");
                console.log("AppDrawer: Loaded " + json.length + " apps.");
            } catch (e) {
                console.log("AppDrawer Parse Error:", e);
            }
            appLoader.rawOutput = "";
        }
    }
    
    function refreshModel(query) {
        appsModel.clear();
        var q = query.toLowerCase();
        for (var i = 0; i < root.allApps.length; i++) {
            var app = root.allApps[i];
            if (q === "" || app.name.toLowerCase().indexOf(q) !== -1) {
                appsModel.append(app);
            }
        }
    }
    
    Component.onCompleted: {
        appLoader.running = true;
    }

    Item {
        id: contentItem
        anchors.centerIn: parent
        width: 650
        height: 700
        opacity: root.isOpened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        
        // Prevent clicks inside from closing the window
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.background
            border.color: Theme.surface
            border.width: 1
            radius: Theme.radius * 2
            clip: true
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16
                
                // Header (Search bar mimic)
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 8
                    color: Theme.surface
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        
                        Text {
                            text: ""
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: Theme.subtext
                        }
                        
                        TextInput {
                            id: searchInput
                            text: ""
                            font.pixelSize: 14
                            color: Theme.text
                            Layout.fillWidth: true
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            
                            // Keyboard Navigation Handlers
                            Keys.onDownPressed: (event) => { appGrid.moveCurrentIndexDown(); event.accepted = true; }
                            Keys.onUpPressed:   (event) => { appGrid.moveCurrentIndexUp();   event.accepted = true; }
                            Keys.onRightPressed:(event) => { appGrid.moveCurrentIndexRight();event.accepted = true; }
                            Keys.onLeftPressed: (event) => { appGrid.moveCurrentIndexLeft(); event.accepted = true; }
                            
                            onAccepted: {
                                if (appsModel.count > 0) {
                                    let idx = appGrid.currentIndex >= 0 && appGrid.currentIndex < appsModel.count ? appGrid.currentIndex : 0;
                                    let app = appsModel.get(idx);
                                    if (app && app.exec) {
                                        Quickshell.execDetached(["sh", "-c", app.exec + " & disown"]);
                                        root.toggle();
                                    }
                                }
                            }
                            
                            Text {
                                text: "Search Applications..."
                                color: Theme.overlay
                                font.pixelSize: 14
                                visible: parent.text === ""
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onTextChanged: {
                                root.refreshModel(text)
                                appGrid.currentIndex = 0 // Reset focus to first item when typing
                            }
                        }
                    }
                }
                
                // Application Grid
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    GridView {
                        id: appGrid
                        anchors.fill: parent
                        model: appsModel
                        clip: true
                        currentIndex: 0
                        keyNavigationEnabled: true
                        
                        cellWidth: parent.width / 4 // 4 columns
                        cellHeight: 125 // Tall enough for larger icon + 2 lines of text
                        
                        delegate: Rectangle {
                            width: appGrid.cellWidth - 12
                            height: appGrid.cellHeight - 12
                            radius: 12
                            
                            property bool isCurrent: index === appGrid.currentIndex
                            
                            color: (itemMouseArea.containsMouse || isCurrent) ? Qt.rgba(255,255,255,0.05) : "transparent"
                            border.color: (itemMouseArea.containsMouse || isCurrent) ? Qt.rgba(255,255,255,0.1) : "transparent"
                            border.width: 1
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8
                                
                                // Render generic icon if needed, or actual image
                                // Note: QuickShell icon resolution might require image://icon/ protocol
                                Image {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 60
                                    Layout.preferredHeight: 60
                                    source: "image://icon/" + model.icon // Use quickshell icon provider
                                    sourceSize.width: 64
                                    sourceSize.height: 64
                                    fillMode: Image.PreserveAspectFit
                                    // Fallback if image path is direct
                                    onStatusChanged: {
                                        if (status === Image.Error && model.icon.indexOf("/") !== -1) {
                                            source = "file://" + model.icon
                                        }
                                    }
                                }
                                
                                Text {
                                    text: model.name
                                    color: Theme.text
                                    font.pixelSize: 13
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                }
                            }
                            
                            MouseArea {
                                id: itemMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // Make sure we launch in background
                                    Quickshell.execDetached(["sh", "-c", model.exec + " & disown"])
                                    root.toggle() // Close drawer after launching
                                }
                            }
                        }
                        
                        ScrollBar.vertical: ScrollBar {
                            active: true
                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: Theme.overlay
                                opacity: parent.active ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                            background: Item {}
                        }
                    }
                }
            }
        }
    }
    
    function toggle() {
        if (isOpened) {
            isOpened = false
            hideTimer.restart()
        } else {
            root.visible = true
            isOpened = true
            searchInput.text = "" // Clear previous search
            appGrid.currentIndex = 0 // Reset selection
            searchInput.forceActiveFocus() // Auto-focus the search bar
        }
    }
}
