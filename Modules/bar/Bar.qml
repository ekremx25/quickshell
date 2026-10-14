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
    readonly property var barLayout: root.backend ? root.backend.barLayout : BarDefaults.createBarConfig()
    readonly property string barPosition: root.backend ? root.backend.barPosition : "top"
    readonly property bool isVertical: root.backend ? root.backend.isVertical : false
    readonly property var workspacesConfig: root.backend ? root.backend.workspacesConfig : BarDefaults.createWorkspacesConfig()

    property BarBackend backend: BarBackend {}


    Item {
        id: screenItem
        required property var modelData

        property bool showWorkspaces: S.ScreenManager.getFilteredScreens("workspaces").some(function(screen) {
            return screen.name === modelData.name;
        })

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
            property real barSize: 48

            // In horizontal mode set height; in vertical mode set width.
            implicitHeight: root.isVertical ? -1 : barSize
            implicitWidth:  root.isVertical ? barSize : -1
            exclusiveZone: barSize
            WlrLayershell.layer: WlrLayer.Top

            // Settings Popup
                Settings {
                    id: settingsMenu
                    screen: modelData
                    onConfigSaved: newConfig => { if (root.backend) root.backend.applyConfig(newConfig); }
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
                border.width: 0
                opacity: 0
                transform: Translate { id: barSlide; y: root.isVertical ? 0 : (root.barPosition === "bottom" ? 8 : -8) }

                Component.onCompleted: Qt.callLater(function() { barEnterAnim.start() })

                ParallelAnimation {
                    id: barEnterAnim
                    NumberAnimation {
                        target: barContent; property: "opacity"
                        from: 0; to: 1; duration: Theme.animMedium; easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: barSlide; property: "y"
                        to: 0; duration: Theme.animMedium; easing.type: Easing.OutCubic
                    }
                }

                // === HORIZONTAL MODE (top/bottom) ===
                // --- LEFT ---
                RowLayout {
                    visible: !root.isVertical
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Repeater {
                        model: root.barLayout.left
                        Loader {
                            id: leftLoader
                            property int itemIndex: index
                            active: !root.isVertical && ((modelData === "Workspaces") ? screenItem.showWorkspaces : true)
                            sourceComponent: moduleCatalog.componentFor(modelData)
                            opacity: 0
                            Timer {
                                interval: leftLoader.itemIndex * 25
                                running: true
                                onTriggered: { leftLoader.opacity = 1 }
                            }
                            Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                // --- CENTER ---
                RowLayout {
                    visible: !root.isVertical
                    anchors.centerIn: parent
                    spacing: 8
                    Repeater {
                        model: root.barLayout.center
                        Loader {
                            id: centerLoader
                            property int itemIndex: index
                            active: !root.isVertical && ((modelData === "Workspaces") ? screenItem.showWorkspaces : true)
                            sourceComponent: moduleCatalog.componentFor(modelData)
                            opacity: 0
                            Timer {
                                interval: centerLoader.itemIndex * 25
                                running: true
                                onTriggered: { centerLoader.opacity = 1 }
                            }
                            Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                // --- RIGHT ---
                RowLayout {
                    visible: !root.isVertical
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Repeater {
                        model: root.barLayout.right
                        Loader {
                            id: rightLoader
                            property int itemIndex: index
                            active: !root.isVertical && ((modelData === "Workspaces") ? screenItem.showWorkspaces : true)
                            sourceComponent: moduleCatalog.componentFor(modelData)
                            opacity: 0
                            Timer {
                                interval: rightLoader.itemIndex * 25
                                running: true
                                onTriggered: { rightLoader.opacity = 1 }
                            }
                            Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
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
                                active: root.isVertical && ((modelData === "Workspaces") ? screenItem.showWorkspaces : true)
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
                                active: root.isVertical && ((modelData === "Workspaces") ? screenItem.showWorkspaces : true)
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
                                active: root.isVertical && ((modelData === "Workspaces") ? screenItem.showWorkspaces : true)
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
