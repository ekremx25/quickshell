import QtQuick
import Qt.labs.platform
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io

import "Launcher"
import "./Workspaces"
import "./Tray"
import "./SysInfo"
import "./Volume"
import "./power"
import "./Calendar"
import "./Notepad"
import "./Weather"
import "./Notifications"
import "./Clipboard"
import "./Settings"

import "./Group"
import "./System" as Sys
import "../../Widgets"
import "../../Services" as S

Variants {
    id: root
    model: S.ScreenManager.getFilteredScreens("bar")




    // --- CONFIG DATA ---
    property var barLayout: ({
        left: ["Launcher", "Calendar"],
        center: ["Workspaces", "Notifications"],
        right: ["Clipboard", "Weather", "Volume", "Tray", "Power"],
        workspaces: {
            format: "arabic",
            style: "fill",
            transparent: false
        }
    })

    // Bar pozisyonu: "top", "bottom", "left", "right"
    property string barPosition: "top"
    property bool isVertical: barPosition === "left" || barPosition === "right"

    // Separate workspace config property - for reactive binding
    property var workspacesConfig: barLayout.workspaces || { format: "arabic", style: "fill", transparent: false }
    onBarLayoutChanged: {
        workspacesConfig = barLayout.workspaces || { format: "arabic", style: "fill", transparent: false };
        console.log("Bar.qml: workspacesConfig updated: " + JSON.stringify(workspacesConfig));
    }

    // Config loaded? (prevent reading again on multiple screens)
    property bool configLoaded: false

    // Module component map (excluding Launcher)
    property var moduleMap: ({
        "Calendar": calendarComp,
        "Notepad": notepadComp,
        "Notifications": notificationsComp,
        "Weather": weatherComp,
        "Volume": volumeComp,
        "Tray": trayComp,
        "Clipboard": clipboardComp,
        "Power": powerComp,

        "PowerGroup": powerGroupComp,
        "SysInfoGroup": sysInfoGroupComp,
        "RamModule": ramModuleComp,
        "RAM": ramComp
    })

    Component { id: calendarComp; Calendar {} }
    Component { id: notepadComp; Notepad {} }
    Component { id: notificationsComp; Notifications {} }
    Component { id: weatherComp; Weather {} }
    Component { id: volumeComp; Volume {} }
    Component { id: trayComp; Tray {} }
    Component { id: clipboardComp; Clipboard {} }
    Component { id: powerComp; Power {} }

    Component { id: powerGroupComp; PowerGroup {} }
    Component { id: sysInfoGroupComp; SysInfoGroup {} }
    Component { id: ramModuleComp; RamModule {} }
    Component { id: ramComp; RamModule {} }

    Item {
        id: screenItem
        required property var modelData

        property bool showWorkspaces: {
            var prefs = S.ScreenManager.screenPreferences["workspaces"];
            if (!prefs || !Array.isArray(prefs) || prefs.length === 0 || prefs.indexOf("all") !== -1) {
                return true;
            }
            if (prefs.indexOf("none") !== -1 || prefs[0] === "none") {
                return false;
            }
            return prefs.indexOf(modelData.name) !== -1;
        }

        Component { id: workspacesComp; Workspaces { monitorName: modelData.name; config: root.workspacesConfig } }

        PanelWindow {
            id: barWindow
            screen: modelData

            // Dinamik anchor'lar pozisyona göre
            anchors {
                left:   root.barPosition !== "right"
                right:  root.barPosition !== "left"
                top:    root.barPosition !== "bottom"
                bottom: root.barPosition !== "top"
            }
            color: "transparent"
            property real barSize: 52

            // Yatay modda height, dikey modda width ayarla
            implicitHeight: root.isVertical ? -1 : barSize
            implicitWidth:  root.isVertical ? barSize : -1
            exclusiveZone: barSize
            WlrLayershell.layer: WlrLayer.Top

            // --- READ CONFIG (Runs inside PanelWindow) ---
            Process {
                id: configReader
                command: ["cat", StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/bar_config.json"]
                property string output: ""
                property string lastConfigContent: ""

                stdout: SplitParser {
                    onRead: data => { configReader.output += data; }
                }
                onExited: {
                    var content = configReader.output.trim();
                    configReader.output = "";
                    
                    if (content === "") return;
                    if (content === configReader.lastConfigContent && root.configLoaded) return;
                    
                    configReader.lastConfigContent = content;

                    try {
                        var cfg = JSON.parse(content);
                        console.log("Bar.qml: Config parsed. format=" + (cfg.workspaces ? cfg.workspaces.format : "none"));
                        

                        if (!cfg.workspaces) {
                            cfg.workspaces = { format: "arabic", style: "fill", transparent: false };
                        }
                        
                        // Bar pozisyonu oku
                        if (cfg.barPosition) {
                            root.barPosition = cfg.barPosition;
                        }
                        
                        root.barLayout = cfg;
                        root.configLoaded = true;
                        console.log("Bar.qml: barLayout SET. format=" + root.barLayout.workspaces.format + " position=" + root.barPosition);
                        
                        // Load Theme
                        if (cfg.theme && cfg.theme.name) {
                            Theme.setTheme(cfg.theme.name);
                        }
                    } catch(e) {
                        console.log("Bar.qml: Parse error: " + e);
                    }
                }
            }

            Timer {
                interval: 500
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    if (!configReader.running) {
                         configReader.output = ""; // clear buffer just in case
                         configReader.running = true;
                    }
                }
            }

            // Settings Popup
            Settings {
                id: settingsMenu
                screen: modelData
                onConfigSaved: (newConfig) => {
                    root.barLayout = newConfig;
                }
            }




            // Launcher Component — signal connection
            Component {
                id: launcherComp
                Launcher {
                    logo: root.barLayout.launcherLogo || ""
                    Component.onCompleted: {
                        settingsRequested.connect(function() {
                            settingsMenu.visible = !settingsMenu.visible;
                        });
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"

                // === YATAY MOD (top/bottom) ===
                // --- LEFT ---
                RowLayout {
                    visible: !root.isVertical
                    anchors { left: parent.left; leftMargin: 15; verticalCenter: parent.verticalCenter }
                    spacing: 18
                    Repeater {
                        model: root.barLayout.left
                        Loader {
                            active: (modelData === "Workspaces") ? screenItem.showWorkspaces : true
                            sourceComponent: {
                                if (modelData === "Launcher") return launcherComp;
                                if (modelData === "Workspaces") return workspacesComp;
                                return root.moduleMap[modelData] || null;
                            }
                        }
                    }
                }

                // --- CENTER ---
                RowLayout {
                    visible: !root.isVertical
                    anchors.centerIn: parent
                    Repeater {
                        model: root.barLayout.center
                        Loader {
                            active: (modelData === "Workspaces") ? screenItem.showWorkspaces : true
                            sourceComponent: {
                                if (modelData === "Launcher") return launcherComp;
                                if (modelData === "Workspaces") return workspacesComp;
                                return root.moduleMap[modelData] || null;
                            }
                        }
                    }
                }

                // --- RIGHT ---
                RowLayout {
                    visible: !root.isVertical
                    anchors { right: parent.right; rightMargin: 15; verticalCenter: parent.verticalCenter }
                    spacing: 15
                    Repeater {
                        model: root.barLayout.right
                        Loader {
                            active: (modelData === "Workspaces") ? screenItem.showWorkspaces : true
                            sourceComponent: {
                                if (modelData === "Launcher") return launcherComp;
                                if (modelData === "Workspaces") return workspacesComp;
                                return root.moduleMap[modelData] || null;
                            }
                        }
                    }
                }

                // === DİKEY MOD (left/right) ===
                // --- TOP (= left modules) ---
                ColumnLayout {
                    visible: root.isVertical
                    anchors { top: parent.top; topMargin: 10; horizontalCenter: parent.horizontalCenter }
                    spacing: 6
                    Repeater {
                        model: root.barLayout.left
                        Item {
                            Layout.preferredWidth: vLeftLoader.item ? vLeftLoader.item.height + 4 : barWindow.barSize - 8
                            Layout.preferredHeight: vLeftLoader.item ? vLeftLoader.item.width + 4 : 40
                            Layout.alignment: Qt.AlignHCenter
                            Loader {
                                id: vLeftLoader
                                active: (modelData === "Workspaces") ? screenItem.showWorkspaces : true
                                sourceComponent: {
                                    if (modelData === "Launcher") return launcherComp;
                                    if (modelData === "Workspaces") return workspacesComp;
                                    return root.moduleMap[modelData] || null;
                                }
                                anchors.centerIn: parent
                                rotation: -90
                            }
                        }
                    }
                }

                // --- CENTER ---
                ColumnLayout {
                    visible: root.isVertical
                    anchors.centerIn: parent
                    spacing: 6
                    Repeater {
                        model: root.barLayout.center
                        Item {
                            Layout.preferredWidth: vCenterLoader.item ? vCenterLoader.item.height + 4 : barWindow.barSize - 8
                            Layout.preferredHeight: vCenterLoader.item ? vCenterLoader.item.width + 4 : 40
                            Layout.alignment: Qt.AlignHCenter
                            Loader {
                                id: vCenterLoader
                                active: (modelData === "Workspaces") ? screenItem.showWorkspaces : true
                                sourceComponent: {
                                    if (modelData === "Launcher") return launcherComp;
                                    if (modelData === "Workspaces") return workspacesComp;
                                    return root.moduleMap[modelData] || null;
                                }
                                anchors.centerIn: parent
                                rotation: -90
                            }
                        }
                    }
                }

                // --- BOTTOM (= right modules) ---
                ColumnLayout {
                    visible: root.isVertical
                    anchors { bottom: parent.bottom; bottomMargin: 10; horizontalCenter: parent.horizontalCenter }
                    spacing: 6
                    Repeater {
                        model: root.barLayout.right
                        Item {
                            Layout.preferredWidth: vRightLoader.item ? vRightLoader.item.height + 4 : barWindow.barSize - 8
                            Layout.preferredHeight: vRightLoader.item ? vRightLoader.item.width + 4 : 40
                            Layout.alignment: Qt.AlignHCenter
                            Loader {
                                id: vRightLoader
                                active: (modelData === "Workspaces") ? screenItem.showWorkspaces : true
                                sourceComponent: {
                                    if (modelData === "Launcher") return launcherComp;
                                    if (modelData === "Workspaces") return workspacesComp;
                                    return root.moduleMap[modelData] || null;
                                }
                                anchors.centerIn: parent
                                rotation: -90
                            }
                        }
                    }

                }
            }
        }
    }
}
