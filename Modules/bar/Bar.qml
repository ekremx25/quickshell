import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "."
import "BarDefaults.js" as BarDefaults

import "./Settings"
import "../../Widgets"
import "../../Services" as S

Variants {
    id: root
    model: S.ScreenManager.getFilteredScreens("bar")
    readonly property var initialBarConfig: BarDefaults.createBarConfig()
    property var barLayout: ({
        left: initialBarConfig.left.slice(),
        center: initialBarConfig.center.slice(),
        right: initialBarConfig.right.slice(),
        workspaces: BarDefaults.clone(initialBarConfig.workspaces)
    })
    property string barPosition: "top"
    property bool isVertical: false
    property var workspacesConfig: BarDefaults.createWorkspacesConfig()

    function syncFromBackend(dataBackend) {
        if (!dataBackend) return;
        root.barLayout = dataBackend.barLayout || root.barLayout;
        root.barPosition = dataBackend.barPosition || "top";
        root.isVertical = !!dataBackend.isVertical;
        root.workspacesConfig = dataBackend.workspacesConfig || root.workspacesConfig;
    }

    BarBackend {
        id: backend
        Component.onCompleted: root.syncFromBackend(backend)
        onBarLayoutChanged: root.syncFromBackend(backend)
        onBarPositionChanged: root.syncFromBackend(backend)
        onIsVerticalChanged: root.syncFromBackend(backend)
        onWorkspacesConfigChanged: root.syncFromBackend(backend)
    }


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

        PanelWindow {
            id: barWindow
            screen: modelData

            // Dynamic anchors based on bar position
            anchors {
                left:   root.barPosition !== "right"
                right:  root.barPosition !== "left"
                top:    root.barPosition !== "bottom"
                bottom: root.barPosition !== "top"
            }
            color: "transparent"
            property real barSize: 46

            // In horizontal mode set height; in vertical mode set width.
            implicitHeight: root.isVertical ? -1 : barSize
            implicitWidth:  root.isVertical ? barSize : -1
            exclusiveZone: barSize
            WlrLayershell.layer: WlrLayer.Top

            // Settings Popup
                Settings {
                    id: settingsMenu
                    screen: modelData
                    onConfigSaved: (newConfig) => {
                        root.syncFromBackend({
                            barLayout: newConfig,
                            barPosition: newConfig.barPosition || root.barPosition,
                            isVertical: (newConfig.barPosition || root.barPosition) === "left" || (newConfig.barPosition || root.barPosition) === "right",
                            workspacesConfig: newConfig.workspaces || root.workspacesConfig
                        });
                    }
                }

            ModuleCatalog {
                id: moduleCatalog
                screenData: modelData
                workspacesConfig: root.workspacesConfig
                launcherLogo: root.barLayout.launcherLogo || ""
                settingsMenu: settingsMenu
            }

            Rectangle {
                id: barContent
                anchors.fill: parent
                color: "transparent"
                opacity: 0
                transform: Translate { id: barSlide; y: root.barPosition === "bottom" ? 52 : -52 }

                Component.onCompleted: Qt.callLater(function() { barEnterAnim.start() })

                ParallelAnimation {
                    id: barEnterAnim
                    NumberAnimation {
                        target: barContent; property: "opacity"
                        from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: barSlide; property: "y"
                        to: 0; duration: 950; easing.type: Easing.OutBack
                    }
                }

                // === HORIZONTAL MODE (top/bottom) ===
                // --- LEFT ---
                RowLayout {
                    visible: !root.isVertical
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 14
                    Repeater {
                        model: root.barLayout.left
                        Loader {
                            id: leftLoader
                            property int itemIndex: index
                            active: (modelData === "Workspaces") ? screenItem.showWorkspaces : true
                            sourceComponent: moduleCatalog.componentFor(modelData)
                            opacity: 0
                            scale: 0.7
                            Timer {
                                interval: 350 + leftLoader.itemIndex * 100
                                running: true
                                onTriggered: { leftLoader.opacity = 1; leftLoader.scale = 1 }
                            }
                            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                            Behavior on scale   { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
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
                            id: centerLoader
                            property int itemIndex: index
                            active: (modelData === "Workspaces") ? screenItem.showWorkspaces : true
                            sourceComponent: moduleCatalog.componentFor(modelData)
                            opacity: 0
                            scale: 0.7
                            Timer {
                                interval: 500 + centerLoader.itemIndex * 100
                                running: true
                                onTriggered: { centerLoader.opacity = 1; centerLoader.scale = 1 }
                            }
                            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                            Behavior on scale   { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                        }
                    }
                }

                // --- RIGHT ---
                RowLayout {
                    visible: !root.isVertical
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 14
                    Repeater {
                        model: root.barLayout.right
                        Loader {
                            id: rightLoader
                            property int itemIndex: index
                            active: (modelData === "Workspaces") ? screenItem.showWorkspaces : true
                            sourceComponent: moduleCatalog.componentFor(modelData)
                            opacity: 0
                            scale: 0.7
                            Timer {
                                interval: 650 + rightLoader.itemIndex * 100
                                running: true
                                onTriggered: { rightLoader.opacity = 1; rightLoader.scale = 1 }
                            }
                            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                            Behavior on scale   { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                        }
                    }
                }

                // === VERTICAL MODE (left/right) ===
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
                                sourceComponent: moduleCatalog.componentFor(modelData)
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
                                sourceComponent: moduleCatalog.componentFor(modelData)
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
                                sourceComponent: moduleCatalog.componentFor(modelData)
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
