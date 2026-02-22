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
import "./VolumeX"
import "./power"
import "./Calendar"
import "./Notepad"
import "./Disk"
import "./Weather"
import "./Notifications"
import "./Clipboard"
import "./Settings"
import "./ClockBlock"

import "./Battery"
import "./PowerProfile"
import "./Group"
import "./System" as Sys
import "../../Widgets"
import "../../Services" as S

Variants {
    id: root
    model: S.ScreenManager.getFilteredScreens("bar")




    // --- CONFIG DATA ---
    property var barLayout: ({
        left: ["Launcher", "Temp", "GPU", "Disk", "Calendar"],
        center: ["Workspaces", "Notifications"],
        right: ["Clipboard", "Weather", "Volume", "Tray", "ControlCenter", "Power"],
        workspaces: {
            format: "arabic",
            style: "fill",
            transparent: false
        }
    })

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
        "Temp": tempComp,
        "GPU": gpuComp,
        "Disk": diskComp,
        "Calendar": calendarComp,
        "Notepad": notepadComp,
        "Notifications": notificationsComp,
        "Weather": weatherComp,
        "Volume": volumeComp,
        "VolumeX": volumeXComp,
        "Tray": trayComp,
        "Clipboard": clipboardComp,
        "Power": powerComp,

        "Battery": batteryComp,
        "PowerProfile": powerProfileComp,
        "PowerGroup": powerGroupComp,
        "SysInfoGroup": sysInfoGroupComp,
        "Clock": clockComp,
        "SysInfo": sysInfoComp,
        "RAM": ramComp
    })

    Component { id: tempComp; Temp {} }
    Component { id: gpuComp; GPU {} }
    Component { id: diskComp; Disk {} }
    Component { id: calendarComp; Calendar {} }
    Component { id: notepadComp; Notepad {} }
    Component { id: notificationsComp; Notifications {} }
    Component { id: weatherComp; Weather {} }
    Component { id: volumeComp; Volume {} }
    Component { id: volumeXComp; VolumeX {} }
    Component { id: trayComp; Tray {} }
    Component { id: clipboardComp; Clipboard {} }
    Component { id: powerComp; Power {} }

    Component { id: batteryComp; Battery {} }
    Component { id: powerProfileComp; PowerProfile {} }
    Component { id: powerGroupComp; PowerGroup {} }
    Component { id: sysInfoGroupComp; SysInfoGroup {} }
    Component { id: clockComp; ClockBlock {} }
    Component { id: sysInfoComp; SystemStats {} }
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

            anchors { left: true; top: true; right: true }
            color: "transparent"
            property real barHeight: 52
            implicitHeight: barHeight
            exclusiveZone: barHeight
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
                    // console.log("Bar.qml: configReader exited. length=" + configReader.output.length);
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
                        
                        root.barLayout = cfg;
                        root.configLoaded = true;
                        console.log("Bar.qml: barLayout SET. format=" + root.barLayout.workspaces.format);
                        
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

                // --- LEFT ---
                RowLayout {
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
            }
        }
    }
}
